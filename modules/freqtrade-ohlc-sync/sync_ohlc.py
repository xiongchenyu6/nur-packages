#!/usr/bin/env python3
"""
Pull recent klines from Binance via CCXT and write them straight into a
TimescaleDB hypertable, then refresh continuous aggregates.

Designed to be idempotent and incremental:
  - For each (pair, tf) we read max(ts) from the destination hypertable
    and only fetch newer candles.
  - On a fresh DB the first run can backfill up to --backfill-days candles.
  - All writes go through a temporary staging table + INSERT … ON CONFLICT
    DO NOTHING so re-running is safe and overlapping ranges don't bloat
    the hypertable.

The script intentionally does NOT depend on freqtrade — it speaks CCXT
directly, which keeps the Nix closure small enough to deploy on aarch64
hosts without dragging in pandas-ta and friends.

Usage (with sops-managed env or explicit env vars):
  TIMESCALE_URL=postgres://… python sync_ohlc.py --pairs BTC/USDT ETH/USDT
"""
from __future__ import annotations

import argparse
import io
import os
import sys
import time
from datetime import datetime, timezone
from typing import Iterable

import ccxt
import psycopg2


SCHEMA = os.environ.get("TIMESCALE_SCHEMA", "quant")
TABLE = os.environ.get("TIMESCALE_TABLE", "ohlc")
DB_URL = os.environ.get("TIMESCALE_URL")
EXCHANGE_ID = os.environ.get("OHLC_EXCHANGE", "binance")

# Continuous-aggregate views to refresh after each sync. Override with the
# `--refresh-views` flag (empty list disables the refresh step).
DEFAULT_REFRESH_VIEWS = ("ohlc_15m", "ohlc_1h", "ohlc_1d")

# CCXT page size — Binance returns max 1000 1m candles per call. Smaller
# values trade throughput for fairness on the public API.
PAGE_LIMIT = 1000


def _connect():
    if not DB_URL:
        sys.exit("TIMESCALE_URL not set (e.g. via systemd EnvironmentFile=)")
    return psycopg2.connect(DB_URL)


def _make_exchange():
    klass = getattr(ccxt, EXCHANGE_ID)
    ex = klass({"enableRateLimit": True})
    ex.load_markets()
    return ex


def _tf_to_seconds(tf: str) -> int:
    units = {"m": 60, "h": 3600, "d": 86400, "w": 604800}
    return int(tf[:-1]) * units[tf[-1]]


def _max_ts(cur, pair: str, tf: str) -> datetime | None:
    cur.execute(
        f"SELECT max(ts) FROM {SCHEMA}.{TABLE} WHERE pair=%s AND tf=%s",
        (pair, tf),
    )
    return cur.fetchone()[0]


def _fetch_since(
    ex, pair: str, tf: str, since_ms: int, until_ms: int
) -> Iterable[list]:
    """Yield (ts_ms, o, h, l, c, v) tuples between since_ms and until_ms."""
    cursor = since_ms
    tf_ms = _tf_to_seconds(tf) * 1000
    while cursor < until_ms:
        batch = ex.fetch_ohlcv(pair, timeframe=tf, since=cursor, limit=PAGE_LIMIT)
        if not batch:
            return
        for row in batch:
            if row[0] >= until_ms:
                return
            yield row
        last_ts = batch[-1][0]
        # Advance cursor by one tf to avoid asking for the same candle twice.
        cursor = last_ts + tf_ms
        # Guard against pathological exchanges that return < 2 rows.
        if len(batch) < 2:
            cursor = max(cursor, last_ts + tf_ms)


def _copy_rows(conn, pair: str, tf: str, rows: list[tuple]) -> int:
    if not rows:
        return 0
    buf = io.StringIO()
    for ts_ms, o, h, l, c, v in rows:
        ts = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).isoformat()
        buf.write(f"{pair}\t{tf}\t{ts}\t{o}\t{h}\t{l}\t{c}\t{v}\n")
    buf.seek(0)
    with conn.cursor() as cur:
        # COPY into a TEMP table, then upsert. This avoids needing a unique
        # index on the hypertable for ON CONFLICT semantics while still
        # being idempotent in the face of overlapping fetches.
        cur.execute(
            f"""
            CREATE TEMP TABLE _stage (
              pair text, tf text, ts timestamptz,
              open double precision, high double precision,
              low double precision, close double precision,
              volume double precision
            ) ON COMMIT DROP
            """
        )
        cur.copy_expert(
            "COPY _stage (pair, tf, ts, open, high, low, close, volume) "
            "FROM STDIN WITH (FORMAT text, DELIMITER E'\\t')",
            buf,
        )
        cur.execute(
            f"""
            INSERT INTO {SCHEMA}.{TABLE} (pair, tf, ts, open, high, low, close, volume)
            SELECT pair, tf, ts, open, high, low, close, volume FROM _stage
            ON CONFLICT (pair, tf, ts) DO NOTHING
            """
        )
        inserted = cur.rowcount
    conn.commit()
    return inserted


def _refresh_aggregates(views: list[str]) -> None:
    if not views:
        return
    fresh = psycopg2.connect(DB_URL)
    fresh.autocommit = True
    try:
        with fresh.cursor() as cur:
            for v in views:
                print(f"  refreshing {SCHEMA}.{v} …", flush=True)
                cur.execute(
                    f"CALL refresh_continuous_aggregate('{SCHEMA}.{v}', NULL, NULL)"
                )
    finally:
        fresh.close()


def sync_pair(conn, ex, pair: str, tf: str, backfill_days: int) -> int:
    tf_ms = _tf_to_seconds(tf) * 1000
    now_ms = int(time.time() * 1000)
    with conn.cursor() as cur:
        last = _max_ts(cur, pair, tf)
    if last is None:
        since_ms = now_ms - backfill_days * 86_400_000
        mode = f"backfill {backfill_days}d"
    else:
        since_ms = int(last.timestamp() * 1000) + tf_ms
        mode = f"incremental from {last.isoformat()}"

    if since_ms >= now_ms:
        print(f"  {pair:<12} {tf}  already current")
        return 0

    rows = list(_fetch_since(ex, pair, tf, since_ms, now_ms))
    if not rows:
        print(f"  {pair:<12} {tf}  {mode:<40}  no rows returned")
        return 0
    n = _copy_rows(conn, pair, tf, rows)
    print(
        f"  {pair:<12} {tf}  {mode:<40}  fetched {len(rows):,}, inserted {n:,}",
        flush=True,
    )
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--pairs",
        nargs="+",
        default=["BTC/USDT", "ETH/USDT", "BNB/USDT", "SOL/USDT"],
        help="CCXT pair symbols (e.g. BTC/USDT).",
    )
    ap.add_argument(
        "--timeframes",
        nargs="+",
        default=["1m"],
        help="CCXT timeframes; only base 1m is needed if downstream views aggregate.",
    )
    ap.add_argument(
        "--backfill-days",
        type=int,
        default=3,
        help="On a fresh hypertable, fetch this many days of history.",
    )
    ap.add_argument(
        "--refresh-views",
        nargs="*",
        default=list(DEFAULT_REFRESH_VIEWS),
        help="Continuous aggregate views to refresh after sync. Pass empty to skip.",
    )
    args = ap.parse_args()

    print(
        f"sync_ohlc → {EXCHANGE_ID} pairs={args.pairs} tfs={args.timeframes} "
        f"target=schema={SCHEMA} table={TABLE}",
        flush=True,
    )
    t0 = time.time()
    ex = _make_exchange()
    total = 0
    with _connect() as conn:
        for pair in args.pairs:
            for tf in args.timeframes:
                try:
                    total += sync_pair(conn, ex, pair, tf, args.backfill_days)
                except Exception as e:  # pragma: no cover — log & continue
                    print(f"  {pair} {tf} ERROR: {e}", flush=True)
        if total > 0 and args.refresh_views:
            print("refreshing continuous aggregates…", flush=True)
            _refresh_aggregates(args.refresh_views)
    print(f"done: {total:,} rows in {time.time() - t0:.1f}s", flush=True)


if __name__ == "__main__":
    main()
