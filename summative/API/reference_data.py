"""The provinces, districts, markets and commodities the model knows.

They come from the training data. /predict uses them to reject unknown names, and
/reference sends them to the app for its suggestions and auto-fill. After an accepted
retrain they are reloaded, so new markets and commodities (e.g. Peaches) become valid.
"""

import difflib
from pathlib import Path

import pandas as pd

from config import TEXT_FEATURE_NAMES, TEXT_FEATURES

# Lists with this many names or fewer are shown in full in error messages.
MAX_NAMES_IN_MESSAGE = 10


def _most_common(values: pd.Series):
    return values.mode().iloc[0]


def build_markets(rows: pd.DataFrame) -> list[dict]:
    """One entry per market with its province, district, latitude and longitude
    (the most common values when a market has several rows)."""
    markets = (
        rows.groupby("market")
        .agg(province=("admin1", _most_common), district=("admin2", _most_common),
             latitude=("latitude", _most_common), longitude=("longitude", _most_common))
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


class ReferenceData:
    def __init__(self) -> None:
        # field -> {lowercase name: canonical spelling}
        self._names: dict[str, dict[str, str]] = {field: {} for field in TEXT_FEATURES}
        self.markets: list[dict] = []
        self.commodities: list[str] = []

    def load(self, training_data_path: Path) -> None:
        rows = pd.read_csv(training_data_path,
                           usecols=TEXT_FEATURES + ["latitude", "longitude"])
        rows = rows.dropna(subset=TEXT_FEATURES)
        for field in TEXT_FEATURES:
            rows[field] = rows[field].astype(str).str.strip()
            names = sorted(rows[field].unique())
            self._names[field] = {name.lower(): name for name in names}
        self.markets = build_markets(rows)
        self.commodities = build_commodities(rows)

    def names(self, field: str) -> list[str]:
        return sorted(self._names[field].values())

    def canonical(self, field: str, value: str) -> str | None:
        """The official spelling of a name (ignoring case and spaces), or None if unknown."""
        return self._names[field].get(value.strip().lower())

    def unknown_name_message(self, field: str, value: str) -> str:
        """A readable message for a name that isn't in the training data."""
        kind = TEXT_FEATURE_NAMES[field]
        names = self.names(field)
        if len(names) <= MAX_NAMES_IN_MESSAGE:
            return f"Unknown {kind}. Use one of: {', '.join(names)}."

        close = difflib.get_close_matches(value.strip(), names, n=3, cutoff=0.6)
        if close:
            return f"Unknown {kind}. Did you mean: {', '.join(close)}?"
        return f"Unknown {kind}. Check the spelling ({len(names)} {kind} names are known)."


# One shared instance. The request schema's validators need it, and Pydantic
# validators can't receive extra arguments, so it lives at module level.
# The model service loads it at startup and reloads it after a retrain.
reference_data = ReferenceData()
