"""Checking and cleaning the rows of an uploaded CSV before retraining."""

from collections import Counter

import pandas as pd

from config import (
    FEATURES,
    MAX_PRICE_RATIO,
    NUMERIC_FEATURES,
    NUMERIC_RANGES,
    TARGET,
    TEXT_FEATURES,
    WHOLE_NUMBER_FEATURES,
)

REQUIRED_COLUMNS = FEATURES + [TARGET]


class UploadError(Exception):
    """The uploaded file can't be used at all. The message is shown to the user."""


def missing_columns(rows: pd.DataFrame) -> list[str]:
    return [column for column in REQUIRED_COLUMNS if column not in rows.columns]


def keep_valid_rows(rows: pd.DataFrame) -> tuple[pd.DataFrame, Counter]:
    """Drop rows that can't be used and count why each one was dropped.

    Returns the valid rows (only the required columns, with clean types) and a
    Counter of {reason: number of rows}.
    """
    missing = missing_columns(rows)
    if missing:
        raise UploadError(f"The file is missing these columns: {', '.join(missing)}.")

    rows = rows[REQUIRED_COLUMNS].copy()
    dropped: Counter = Counter()

    for column in TEXT_FEATURES:
        rows[column] = rows[column].astype("string").str.strip().replace("", pd.NA)
    for column in NUMERIC_FEATURES + [TARGET]:
        rows[column] = pd.to_numeric(rows[column], errors="coerce")  # text -> NaN

    rows = _drop(rows, rows.isna().any(axis=1), "missing or non-numeric values", dropped)
    rows = _drop(rows, rows[TARGET] <= 0, "price is zero or negative", dropped)
    rows = _drop(rows, ~_numbers_in_range(rows), "number out of range", dropped)

    for column in WHOLE_NUMBER_FEATURES:
        rows[column] = rows[column].astype(int)
    return rows.reset_index(drop=True), dropped


def is_plausible_price(rows: pd.DataFrame, reference_rows: pd.DataFrame) -> pd.Series:
    """True for prices within 10x of their commodity's median (the notebook's cleaning rule).

    The median is computed on reference_rows + rows together, so a commodity that
    only appears in the upload still gets a median.
    """
    all_rows = pd.concat([reference_rows[["commodity", TARGET]], rows[["commodity", TARGET]]])
    medians = all_rows.groupby("commodity")[TARGET].median()
    ratio = rows[TARGET] / rows["commodity"].map(medians)
    return ratio.between(1 / MAX_PRICE_RATIO, MAX_PRICE_RATIO)


def drop_implausible_prices(
    rows: pd.DataFrame, reference_rows: pd.DataFrame, dropped: Counter
) -> pd.DataFrame:
    reason = f"price more than {MAX_PRICE_RATIO}x above or below its commodity's median"
    rows = _drop(rows, ~is_plausible_price(rows, reference_rows), reason, dropped)
    return rows.reset_index(drop=True)


def _numbers_in_range(rows: pd.DataFrame) -> pd.Series:
    in_range = pd.Series(True, index=rows.index)
    for column, (low, high) in NUMERIC_RANGES.items():
        in_range &= rows[column].between(low, high)
    for column in WHOLE_NUMBER_FEATURES:
        in_range &= rows[column] == rows[column].round()
    return in_range


def _drop(rows: pd.DataFrame, to_drop: pd.Series, reason: str, dropped: Counter) -> pd.DataFrame:
    count = int(to_drop.sum())
    if count:
        dropped[reason] += count
    return rows[~to_drop]
