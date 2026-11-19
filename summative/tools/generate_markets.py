"""Write the market and commodity lists that are built into the Flutter app.

The app shows these at once and offline. When the API answers, it switches to the API's
/reference lists, which also include names added by a retrain. Both come from the same
functions in API/reference_data.py.

Reads API/data/training_data.csv and writes:
- FlutterApp/assets/markets.json: one entry per market with its province, district,
  latitude and longitude
- FlutterApp/assets/commodities.json: the commodity names, sorted

Run from the summative folder:  uv run python tools/generate_markets.py
"""

import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "API"))

from reference_data import build_commodities, build_markets  # noqa: E402

TRAINING_DATA = ROOT / "API" / "data" / "training_data.csv"
ASSETS = ROOT / "FlutterApp" / "assets"


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(data)} entries to {path.relative_to(ROOT)}")


def main() -> None:
    rows = pd.read_csv(TRAINING_DATA)
    ASSETS.mkdir(exist_ok=True)
    write_json(ASSETS / "markets.json", build_markets(rows))
    write_json(ASSETS / "commodities.json", build_commodities(rows))


if __name__ == "__main__":
    main()
