"""Settings shared by the whole API: file paths, the model's inputs and their allowed ranges.

Everything that both the request schema and the CSV upload check need lives here,
so the rules are written only once.
"""

import os
from dataclasses import dataclass
from pathlib import Path

API_DIR = Path(__file__).resolve().parent

NUMERIC_FEATURES = ["year", "month", "latitude", "longitude"]
TEXT_FEATURES = ["admin1", "admin2", "market", "commodity"]
FEATURES = NUMERIC_FEATURES + TEXT_FEATURES
TARGET = "price"  # RWF per kg

# Allowed range (inclusive) for each numeric input. Same table as the shared contract.
NUMERIC_RANGES = {
    "year": (2008, 2035),
    "month": (1, 12),
    "latitude": (-2.9, -1.0),
    "longitude": (28.8, 31.0),
}
WHOLE_NUMBER_FEATURES = ["year", "month"]

# Human names for the text inputs, used in error messages.
TEXT_FEATURE_NAMES = {
    "admin1": "province",
    "admin2": "district",
    "market": "market",
    "commodity": "commodity",
}

# Prices more than this many times above or below their commodity's median are
# treated as typing errors (the same rule as the notebook).
MAX_PRICE_RATIO = 10

# The price range shown in the app should contain 8 out of 10 real prices.
RANGE_COVERAGE_PERCENT = 80

# /retrain needs at least this many rows to measure accuracy and to keep the
# latest month aside as the check set.
MIN_ROWS_FOR_CHECKS = 200

# Before retraining, an upload must follow the usual pattern of cheap and expensive
# foods: the correlation between its log prices and the model's (log) predictions
# must be at least this. It compares *which* foods and markets are cheap or
# expensive, not the price level, so real price rises still pass (all prices x2
# scored 0.97, the same as real 2026 data), while shuffled prices score about 0
# and half-shuffled prices about 0.5. 0.7 sits safely between the two.
MIN_PRICE_PATTERN_MATCH = 0.7

# With fewer rows the correlation is too noisy to judge, so the check is skipped.
MIN_ROWS_FOR_PATTERN_CHECK = 50

RANDOM_STATE = 42


@dataclass(frozen=True)
class Paths:
    """Where the API reads and writes its files. Tests point this at a temporary copy."""

    root: Path = API_DIR

    @property
    def original_model(self) -> Path:
        return self.root / "model" / "best_model.joblib"  # never overwritten

    @property
    def current_model(self) -> Path:
        return self.root / "model" / "current_model.joblib"

    @property
    def previous_model(self) -> Path:
        return self.root / "model" / "previous_model.joblib"

    @property
    def model_info(self) -> Path:
        return self.root / "model" / "model_info.json"

    @property
    def previous_model_info(self) -> Path:
        return self.root / "model" / "previous_model_info.json"

    @property
    def training_data(self) -> Path:
        return self.root / "data" / "training_data.csv"

    @property
    def previous_training_data(self) -> Path:
        return self.root / "data" / "previous_training_data.csv"


def allowed_origins() -> list[str]:
    """Websites allowed to call the API from a browser (see the CORS comment in main.py).

    Set ALLOWED_ORIGINS on Render as a comma-separated list to change it.
    """
    default = "https://your-service.onrender.com,http://localhost:5000"
    value = os.environ.get("ALLOWED_ORIGINS", default)
    return [origin.strip() for origin in value.split(",") if origin.strip()]
