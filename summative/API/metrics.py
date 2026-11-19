"""How we measure a model's accuracy. Used by /retrain and by tools/measure_band.py."""

import numpy as np
import pandas as pd

from config import FEATURES, RANGE_COVERAGE_PERCENT, TARGET


def predict_prices(model, rows: pd.DataFrame) -> np.ndarray:
    """The model predicts log prices; turn them back into RWF per kg."""
    return np.expm1(model.predict(rows[FEATURES]))


def log_mse(model, rows: pd.DataFrame) -> float:
    """MSE on log prices, the same loss the notebook uses to compare models."""
    actual_log = np.log1p(rows[TARGET].to_numpy())
    return float(np.mean((actual_log - model.predict(rows[FEATURES])) ** 2))


def typical_error_percent(mse_log: float) -> float:
    """Turn a log MSE into "typically X% off", the same formula as the notebook.

    An error of e on the log scale means the price is off by a factor of e^e,
    so (e^RMSE - 1) * 100 is the typical error in percent.
    """
    return float((np.exp(np.sqrt(mse_log)) - 1) * 100)


def band_percent(model, rows: pd.DataFrame) -> float:
    """The +/- band (in %) that contains 8 out of 10 real prices.

    We take the 80th percentile of |ln(actual / predicted)| and convert it to a
    percentage. Measure it on rows the model has never seen and that are newer
    than its training data, so the range is honest about future prices.
    """
    actual = rows[TARGET].to_numpy()
    predicted = predict_prices(model, rows)
    log_ratio = np.abs(np.log(actual / predicted))
    return float((np.exp(np.percentile(log_ratio, RANGE_COVERAGE_PERCENT)) - 1) * 100)


def price_pattern_match(model, rows: pd.DataFrame) -> float:
    """How well the prices follow the pattern the model knows (correlation, -1 to 1).

    Computed on log prices, so a few very expensive foods don't dominate. It
    compares which foods and markets are cheap or expensive, not the price level,
    so a real price rise keeps a high score but shuffled prices don't.
    """
    actual_log = np.log1p(rows[TARGET].to_numpy())
    predicted_log = model.predict(rows[FEATURES])
    return float(np.corrcoef(actual_log, predicted_log)[0, 1])


def price_range(predicted_price: float, band: float) -> tuple[float, float]:
    """Low and high end of the likely price range for one prediction."""
    factor = 1 + band / 100
    return predicted_price / factor, predicted_price * factor
