# freqtrade-ohlc-sync

NixOS module that periodically pulls recent OHLC candles from a CCXT-supported
exchange (default: Binance) and writes them into a TimescaleDB hypertable,
then refreshes the continuous aggregates that downstream apps query.

It does **not** depend on freqtrade — only `python3`, `ccxt`, and
`psycopg2` — so the closure is small enough to deploy on aarch64 hosts.

## What it expects on the database side

A hypertable with this shape (column types, names, and unique key are fixed):

```sql
CREATE TABLE quant.ohlc (
  pair    text,
  tf      text,
  ts      timestamptz,
  open    double precision,
  high    double precision,
  low     double precision,
  close   double precision,
  volume  double precision,
  PRIMARY KEY (pair, tf, ts)          -- required for ON CONFLICT DO NOTHING
);
SELECT create_hypertable('quant.ohlc', 'ts');
```

Optional continuous aggregates that the module will refresh after each sync:

```sql
CREATE MATERIALIZED VIEW quant.ohlc_15m WITH (timescaledb.continuous) AS …;
CREATE MATERIALIZED VIEW quant.ohlc_1h  WITH (timescaledb.continuous) AS …;
CREATE MATERIALIZED VIEW quant.ohlc_1d  WITH (timescaledb.continuous) AS …;
```

If you don't have aggregates, set `services.freqtrade-ohlc-sync.refreshViews = [];`.

## Usage

```nix
{
  imports = [ inputs.xiongchenyu6.nixosModules.freqtrade-ohlc-sync ];

  sops.secrets."ohlc-sync/db-url" = { };
  sops.templates."ohlc-sync.env".content = ''
    TIMESCALE_URL=postgres://quant_writer:${config.sops.placeholder."ohlc-sync/db-url"}@127.0.0.1:5432/api
  '';

  services.freqtrade-ohlc-sync = {
    enable = true;
    pairs = [ "BTC/USDT" "ETH/USDT" "BNB/USDT" "SOL/USDT" ];
    timeframes = [ "1m" ];
    schema = "quant";
    onCalendar = "*:0/15";   # every 15 minutes
    environmentFile = config.sops.templates."ohlc-sync.env".path;
  };
}
```

## Operations

```bash
# Run once
sudo systemctl start freqtrade-ohlc-sync.service

# See the next firing
systemctl list-timers freqtrade-ohlc-sync.timer

# Watch live
journalctl -u freqtrade-ohlc-sync.service -f
```

The first run on an empty hypertable backfills `backfillDays` of 1m candles
(default 3). Subsequent runs are incremental from `max(ts)` per `(pair, tf)`,
so a 15-minute cadence inserts only ~15 rows per pair per tick.
