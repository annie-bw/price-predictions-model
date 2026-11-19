"""Write the market and commodity lists the Flutter app uses for suggestions and auto-fill.

Reads API/data/training_data.csv and writes:
- FlutterApp/assets/markets.json: one entry per market with its province, district,
  latitude and longitude (the most common values when a market has several rows)
- FlutterApp/assets/commodities.json: the commodity names, sorted

Run from the summative folder:  uv run python tools/generate_markets.py
"""

import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
TRAINING_DATA = ROOT / "API" / "data" / "training_data.csv"
ASSETS = ROOT / "FlutterApp" / "assets"


def most_common(values: pd.Series):
    return values.mode().iloc[0]


def build_markets(rows: pd.DataFrame) -> list[dict]:
    markets = (
        rows.groupby("market")
        .agg(province=("admin1", most_common), district=("admin2", most_common),
             latitude=("latitude", most_common), longitude=("longitude", most_common))
        .reset_index()
        .sort_values("market")
    )
    return [
        {"market": row.market, "province": row.province, "district": row.district,
         "latitude": float(row.latitude), "longitude": float(row.longitude)}
        for row in markets.itertuples()
    ]


def build_commodities(rows: pd.DataFrame) -> list[str]:
    return sorted(rows["commodity"].dropna().unique().tolist())


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
