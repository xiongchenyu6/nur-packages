"""Fetch the crypto Fear & Greed history (alternative.me) to a CSV the accumulator
reads via the FNG_CSV env var. Run as ExecStartPre. stdlib only.

SSL_CERT_FILE must point at a CA bundle (the NixOS module sets it from pkgs.cacert).
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import sys
import urllib.request

URL = "https://api.alternative.me/fng/?limit=0&format=json"


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "fng_history.csv"
    req = urllib.request.Request(URL, headers={"User-Agent": "nautilus-accumulator"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)["data"]
    rows = []
    for x in data:
        ts = int(x["timestamp"])
        date = dt.datetime.fromtimestamp(ts, tz=dt.timezone.utc).strftime("%Y-%m-%d")
        rows.append((ts, date, x["value"], x["value_classification"]))
    rows.sort(key=lambda r: -r[0])
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["timestamp", "date", "value", "classification"])
        w.writerows(rows)
    print(f"fng: wrote {len(rows)} rows to {out}; newest {rows[0][1]}={rows[0][2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
