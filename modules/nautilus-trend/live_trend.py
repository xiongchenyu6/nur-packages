"""Live crypto trend follower on NautilusTrader (Binance) — the HonestTrend15mProtections
strategy running live, testnet by default. Same event-driven class as the equity trend.

Credentials/env mirror live_accumulation.py:
  BINANCE_API_KEY, BINANCE_API_SECRET or BINANCE_API_SECRET_FILE (Ed25519 PEM),
  BINANCE_TESTNET=1 (default), BINANCE_BAR (default 15-MINUTE-LAST-EXTERNAL),
  TREND_INSTRUMENT (default BTCUSDT.BINANCE), FNG_CSV (optional regime gate).

Validate wiring offline:  python live_trend.py --check
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from nautilus_trader.adapters.binance import BINANCE_VENUE
from nautilus_trader.adapters.binance.common.enums import BinanceAccountType, BinanceEnvironment
from nautilus_trader.adapters.binance.config import BinanceDataClientConfig, BinanceExecClientConfig
from nautilus_trader.adapters.binance.factories import (
    BinanceLiveDataClientFactory,
    BinanceLiveExecClientFactory,
)
from nautilus_trader.config import InstrumentProviderConfig, LoggingConfig, TradingNodeConfig
from nautilus_trader.live.node import TradingNode
from nautilus_trader.model.data import BarType

_HERE = Path(__file__).resolve().parent
for _p in (str(_HERE), str(_HERE.parent / "nautilus_equity")):
    if _p not in sys.path:
        sys.path.insert(0, _p)
from honest_trend_equity import HonestTrendEquity, HonestTrendEquityConfig  # noqa: E402


def _secret() -> str:
    s = os.environ.get("BINANCE_API_SECRET")
    if not s:
        f = os.environ.get("BINANCE_API_SECRET_FILE")
        if f and Path(f).exists():
            s = Path(f).read_text().strip()
    return s or "CHECK_ONLY_NO_CONNECT"


def build_node() -> TradingNode:
    testnet = os.environ.get("BINANCE_TESTNET", "1") != "0"
    env = BinanceEnvironment.TESTNET if testnet else BinanceEnvironment.LIVE
    api_key = os.environ.get("BINANCE_API_KEY") or "CHECK_ONLY_NO_CONNECT"
    api_secret = _secret()
    provider = InstrumentProviderConfig(load_all=True)

    config = TradingNodeConfig(
        trader_id="TREND-001",
        logging=LoggingConfig(log_level="INFO"),
        data_clients={
            "BINANCE": BinanceDataClientConfig(
                api_key=api_key, api_secret=api_secret,
                account_type=BinanceAccountType.SPOT, environment=env,
                instrument_provider=provider,
            )
        },
        exec_clients={
            "BINANCE": BinanceExecClientConfig(
                api_key=api_key, api_secret=api_secret,
                account_type=BinanceAccountType.SPOT, environment=env,
                instrument_provider=provider,
            )
        },
    )
    node = TradingNode(config=config)
    node.add_data_client_factory("BINANCE", BinanceLiveDataClientFactory)
    node.add_exec_client_factory("BINANCE", BinanceLiveExecClientFactory)
    node.build()

    instrument = os.environ.get("TREND_INSTRUMENT", "BTCUSDT.BINANCE")
    bar_spec = os.environ.get("BINANCE_BAR", "15-MINUTE-LAST-EXTERNAL")
    fng = os.environ.get("FNG_CSV")
    strategy = HonestTrendEquity(HonestTrendEquityConfig(
        instrument_id=instrument,
        bar_type=BarType.from_str(f"{instrument}-{bar_spec}"),
        ema_fast=72, ema_slow=144, adx_period=14, adx_threshold=18.0,
        vol_window=96, min_hold_bars=48, risk_frac=0.10,
        stop_loss_pct=0.0, rth_only=False,
        regime_csv=fng if (fng and Path(fng).exists()) else None,
        regime_threshold=80.0, regime_mode="block_above",
    ))
    node.trader.add_strategy(strategy)
    return node


def main() -> int:
    check_only = "--check" in sys.argv
    has_keys = bool(os.environ.get("BINANCE_API_KEY")) and (
        bool(os.environ.get("BINANCE_API_SECRET"))
        or (os.environ.get("BINANCE_API_SECRET_FILE") and Path(os.environ["BINANCE_API_SECRET_FILE"]).exists())
    )
    node = build_node()
    print(f"Trend TradingNode built OK (venue={BINANCE_VENUE}, "
          f"testnet={os.environ.get('BINANCE_TESTNET','1') != '0'})")
    if check_only or not has_keys:
        if not has_keys:
            print("No BINANCE creds in env → not connecting.")
        node.dispose()
        return 0
    try:
        node.run()
    finally:
        node.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
