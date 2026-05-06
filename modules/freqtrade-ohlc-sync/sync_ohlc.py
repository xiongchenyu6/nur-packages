#!/usr/bin/env python3
"""
Pull recent klines from Binance and write them straight into a TimescaleDB
hypertable, then refresh continuous aggregates.

Designed to be idempotent and incremental:
  - For each (pair, tf) we read max(ts) from the destination hypertable
    and only fetch newer candles.
  - On a fresh DB the first run can backfill up to --backfill-days candles.
  - All writes COPY into a TEMP table and INSERT … ON CONFLICT DO NOTHING,
    so re-running with overlapping ranges is safe.

Talks to Binance's public REST endpoint directly (no ccxt / freqtrade
dependency), keeping the closure tiny on aarch64.

Usage (env-driven):
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

import psycopg2
import requests


SCHEMA = os.environ.get("TIMESCALE_SCHEMA", "quant")
TABLE = os.environ.get("TIMESCALE_TABLE", "ohlc")
DB_URL = os.environ.get("TIMESCALE_URL")

# Default to spot. For USDT-M futures override BINANCE_BASE to
# https://fapi.binance.com and BINANCE_KLINES_PATH to /fapi/v1/klines.
BINANCE_BASE = os.environ.get("BINANCE_BASE", "https://api.binance.com")
BINANCE_KLINES_PATH = os.environ.get("BINANCE_KLINES_PATH", "/api/v3/klines")

# Continuous-aggregate views to refresh after each sync.
DEFAULT_REFRESH_VIEWS = ("ohlc_15m", "ohlc_1h", "ohlc_1d")

# Binance returns max 1000 1m candles per call.
PAGE_LIMIT = 1000

# Per-tf seconds; Binance interval strings happen to match.
_TF_SECONDS = {
    "1m": 60, "3m": 180, "5m": 300, "15m": 900, "30m": 1800,
    "1h": 3600, "2h": 7200, "4h": 14400, "6h": 21600, "8h": 28800, "12h": 43200,
    "1d": 86400, "3d": 259200, "1w": 604800, "1M": 2592000,
}


def _connect():
    if not DB_URL:
        sys.exit("TIMESCALE_URL not set (e.g. via systemd EnvironmentFile=)")
    return psycopg2.connect(DB_URL)


def _binance_symbol(pair: str) -> str:
    """`BTC/USDT` → `BTCUSDT`. Binance ignores the `/`."""
    return pair.replace("/", "")


def _max_ts(cur, pair: str, tf: str) -> datetime | None:
    cur.execute(
        f"SELECT max(ts) FROM {SCHEMA}.{TABLE} WHERE pair=%s AND tf=%s",
        (pair, tf),
    )
    return cur.fetchone()[0]


def _fetch_klines(pair: str, tf: str, since_ms: int, until_ms: int) -> Iterable[list]:
    """Yield Binance klines [openTime_ms, o, h, l, c, v] between since/until."""
    if tf not in _TF_SECONDS:
        raise ValueError(f"unsupported timeframe: {tf}")
    tf_ms = _TF_SECONDS[tf] * 1000
    cursor = since_ms
    sym = _binance_symbol(pair)
    sess = requests.Session()
    sess.headers.update({"User-Agent": "freqtrade-ohlc-sync/1.0"})
    while cursor < until_ms:
        params = {
            "symbol": sym,
            "interval": tf,
            "startTime": cursor,
            "endTime": min(until_ms, cursor + PAGE_LIMIT * tf_ms),
            "limit": PAGE_LIMIT,
        }
        r = sess.get(BINANCE_BASE + BINANCE_KLINES_PATH, params=params, timeout=20)
        r.raise_for_status()
        batch = r.json()
        if not batch:
            return
        for row in batch:
            # row[0]=openTime ms, [1..5] strings o,h,l,c,v
            yield [row[0], float(row[1]), float(row[2]), float(row[3]),
                   float(row[4]), float(row[5])]
        last_ts = batch[-1][0]
        cursor = last_ts + tf_ms
        # Hard cap on total rows per pair/run to avoid runaway pulls.
        # Binance's REST is generously rate-limited; we stay polite anyway.
        time.sleep(0.05)


def _copy_rows(conn, pair: str, tf: str, rows: list[list]) -> int:
    if not rows:
        return 0
    buf = io.StringIO()
    for ts_ms, o, h, l, c, v in rows:
        ts = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).isoformat()
        buf.write(f"{pair}\t{tf}\t{ts}\t{o}\t{h}\t{l}\t{c}\t{v}\n")
    buf.seek(0)
    with conn.cursor() as cur:
        cur.execute(
            """
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


def sync_pair(conn, pair: str, tf: str, backfill_days: int) -> int:
    tf_ms = _TF_SECONDS[tf] * 1000
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

    rows = list(_fetch_klines(pair, tf, since_ms, now_ms))
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
        help="Pair symbols using slash notation (BTC/USDT). "
             "Translated to Binance `BTCUSDT` automatically.",
    )
    ap.add_argument(
        "--timeframes",
        nargs="+",
        default=["1m"],
        help="Binance interval strings; usually just `1m` if downstream "
             "TimescaleDB continuous aggregates derive higher tfs.",
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
        help="Continuous aggregate views to refresh. Pass empty to skip.",
    )
    args = ap.parse_args()

    print(
        f"sync_ohlc → {BINANCE_BASE}{BINANCE_KLINES_PATH} pairs={args.pairs} "
        f"tfs={args.timeframes} target=schema={SCHEMA} table={TABLE}",
        flush=True,
    )
    t0 = time.time()
    total = 0
    with _connect() as conn:
        for pair in args.pairs:
            for tf in args.timeframes:
                try:
                    total += sync_pair(conn, pair, tf, args.backfill_days)
                except Exception as e:  # pragma: no cover — log & continue
                    print(f"  {pair} {tf} ERROR: {e}", flush=True)
        if total > 0 and args.refresh_views:
            print("refreshing continuous aggregates…", flush=True)
            _refresh_aggregates(args.refresh_views)
    print(f"done: {total:,} rows in {time.time() - t0:.1f}s", flush=True)


if __name__ == "__main__":
    main()
