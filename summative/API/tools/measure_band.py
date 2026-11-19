"""Measure the price-range band of the original model on data it has never seen.

Runs best_model.pkl on the 2026 rows (newer than anything it trained on) and
writes model/model_info.json, which the API loads at startup.

Run from the API folder:  python tools/measure_band.py
"""

import json
import sys
from pathlib import Path

import joblib
import pandas as pd

API_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(API_DIR))  # so we can reuse the API's own metric functions

import metrics  # noqa: E402

NEW_DATA = API_DIR.parent / "linear_regression" / "data" / "new_data.csv"
MODEL = API_DIR / "best_model.pkl"
OUTPUT = API_DIR / "model" / "model_info.json"


def main() -> None:
    model = joblib.load(MODEL)
    new_rows = pd.read_csv(NEW_DATA)

    band = metrics.band_percent(model, new_rows)
    typical = metrics.typical_error_percent(metrics.log_mse(model, new_rows))

    info = {
        "band_percent": round(band, 1),
        "measured_on": "new_data.csv (2026)",
        "rows": len(new_rows),
        "model_version": "original",
    }
    OUTPUT.write_text(json.dumps(info, indent=2), encoding="utf-8")

    print(f"Typical error on new data: {typical:.1f}%")
    print(f"80% band: ±{band:.1f}%  ->  wrote {OUTPUT}")


if __name__ == "__main__":
    main()
