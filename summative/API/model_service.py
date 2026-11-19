"""Loads the model, makes predictions, retrains it with a quality check, and keeps a backup.

All ML logic lives here, so main.py only deals with HTTP.
"""

import json
import shutil
import threading
from collections import Counter
from dataclasses import dataclass

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OrdinalEncoder, StandardScaler

import metrics
from cleaning import UploadError, drop_implausible_prices, keep_valid_rows
from config import (
    FEATURES,
    MIN_PRICE_PATTERN_MATCH,
    MIN_ROWS_FOR_CHECKS,
    MIN_ROWS_FOR_PATTERN_CHECK,
    NUMERIC_FEATURES,
    RANDOM_STATE,
    TARGET,
    TEXT_FEATURES,
    Paths,
)
from reference_data import reference_data

ORIGINAL = "original"
RETRAINED = "retrained"


class RetrainBusyError(Exception):
    """Another retrain or rollback is already running."""


class NoBackupError(Exception):
    """There is no previous model to roll back to."""


class TrainingError(Exception):
    """Training the candidate model failed. The model in use keeps serving."""


@dataclass
class ServingModel:
    """The model in use plus the facts that belong to it. Swapped as one object."""

    pipeline: Pipeline
    version: str
    info: dict  # contents of model_info.json, e.g. {"band_percent": 26.6, ...}

    @property
    def band_percent(self) -> float:
        return float(self.info["band_percent"])


@dataclass
class CheckSplit:
    learn_rows: pd.DataFrame
    check_rows: pd.DataFrame
    description: str


def build_pipeline() -> Pipeline:
    """The notebook's best model: a Random Forest on ordinal-encoded text columns."""
    preprocess = ColumnTransformer([
        ("numeric", StandardScaler(), NUMERIC_FEATURES),
        ("categorical",
         OrdinalEncoder(handle_unknown="use_encoded_value", unknown_value=-1),
         TEXT_FEATURES),
    ])
    forest = RandomForestRegressor(
        n_estimators=50, max_features=0.8, min_samples_leaf=3,
        n_jobs=-1, random_state=RANDOM_STATE,
    )
    return Pipeline([("preprocess", preprocess), ("model", forest)])


def train(rows: pd.DataFrame) -> Pipeline:
    """Train a new pipeline. The model learns log prices, like in the notebook."""
    return build_pipeline().fit(rows[FEATURES], np.log1p(rows[TARGET]))


class ModelService:
    def __init__(self, paths: Paths) -> None:
        self.paths = paths
        # Held for the whole of a retrain or rollback, so two can't run at once.
        self._retrain_lock = threading.Lock()
        # Held only while reading or swapping the model, so a swap is atomic.
        self._swap_lock = threading.Lock()
        self._serving = self._load_serving_model()
        # The backup (previous model) is kept on disk only, not in memory: a local
        # retrain peaked at about 500 MB with it in memory, and Render's free plan
        # has 512 MB. Rollback loads it back from model/previous_model.joblib.
        reference_data.load(paths.training_data)

    # ---------- predict ----------

    @property
    def serving(self) -> ServingModel:
        with self._swap_lock:
            return self._serving

    def predict(self, inputs: dict) -> dict:
        serving = self.serving  # one consistent snapshot of model + band
        row = pd.DataFrame([inputs])[FEATURES]
        price = float(np.expm1(serving.pipeline.predict(row)[0]))
        low, high = metrics.price_range(price, serving.band_percent)
        return {"predicted_price": round(price, 1), "low": round(low, 1), "high": round(high, 1)}

    # ---------- retrain ----------

    def retrain(self, uploaded_rows: pd.DataFrame) -> dict:
        if not self._retrain_lock.acquire(blocking=False):
            raise RetrainBusyError("A retrain is already running. Try again in a minute.")
        try:
            return self._retrain(uploaded_rows)
        finally:
            self._retrain_lock.release()

    def _retrain(self, uploaded_rows: pd.DataFrame) -> dict:
        current = self.serving
        training_rows = pd.read_csv(self.paths.training_data)

        # 1-2. Keep only usable rows, then apply the notebook's cleaning rule.
        new_rows, dropped = keep_valid_rows(uploaded_rows)
        new_rows = drop_implausible_prices(new_rows, training_rows, dropped)
        if new_rows.empty:
            raise UploadError("No valid rows are left after checking the file. " + _reasons_text(dropped))

        # 2b. How far off was the current model on these unseen, newer rows?
        accuracy = self._accuracy_on_new_rows(current, new_rows)
        result = {
            "rows_received": len(uploaded_rows),
            "rows_used": len(new_rows),
            "rows_dropped": sum(dropped.values()),
            "dropped_reasons": dict(dropped),
            "accuracy_on_new_data": accuracy,
        }

        # 2c. Do the prices look like real prices? If the whole file is shuffled,
        # the newest-month check below is shuffled too and can't catch it.
        pattern = self._price_pattern_match(current, new_rows)
        result["price_pattern_match"] = pattern
        if pattern is not None and pattern < MIN_PRICE_PATTERN_MATCH:
            return {**result, "accepted": False, "message": _pattern_message(pattern),
                    "model_version": current.version}

        # 3. Keep rows aside that neither model trains on, to compare them fairly.
        split = split_check_set(new_rows)

        # 4. Train the candidate into a new variable; the current model keeps serving.
        try:
            candidate = train(pd.concat([training_rows, split.learn_rows], ignore_index=True))
        except Exception as error:  # report any training problem as a 500
            raise TrainingError(f"Training the new model failed: {error}") from error

        # 5. Quality check: accept only if the candidate is at least as good.
        current_mse = metrics.log_mse(current.pipeline, split.check_rows)
        candidate_mse = metrics.log_mse(candidate, split.check_rows)
        del candidate  # free memory before the final fit
        accepted = candidate_mse <= current_mse

        if accepted:
            # 6. Refit on everything, so no new data is wasted, then swap it in.
            self._accept(training_rows, new_rows, accuracy)

        return {
            **result,
            "accepted": accepted,
            "message": _decision_message(accepted, current_mse, candidate_mse),
            "check_set": split.description,
            "check_set_rows": len(split.check_rows),
            "current_model_mse": round(current_mse, 4),
            "candidate_model_mse": round(candidate_mse, 4),
            "model_version": self.serving.version,
        }

    @staticmethod
    def _price_pattern_match(current: ServingModel, new_rows: pd.DataFrame) -> float | None:
        """The pattern score, or None when there are too few rows to judge."""
        if len(new_rows) < MIN_ROWS_FOR_PATTERN_CHECK:
            return None
        return round(metrics.price_pattern_match(current.pipeline, new_rows), 2)

    def _accuracy_on_new_rows(self, current: ServingModel, new_rows: pd.DataFrame) -> dict:
        if len(new_rows) < MIN_ROWS_FOR_CHECKS:
            return {
                "measured": False,
                "rows": len(new_rows),
                "message": f"Only {len(new_rows)} valid rows, so the price range was not re-measured "
                           f"(at least {MIN_ROWS_FOR_CHECKS} are needed). The old range is kept.",
            }
        typical = metrics.typical_error_percent(metrics.log_mse(current.pipeline, new_rows))
        band = metrics.band_percent(current.pipeline, new_rows)
        return {
            "measured": True,
            "rows": len(new_rows),
            "typical_error_percent": round(typical, 1),
            "band_percent": round(band, 1),
            "message": f"Before retraining, the model was typically {typical:.0f}% off on your new data; "
                       f"8 in 10 prices were within ±{band:.0f}%.",
        }

    def _accept(self, training_rows: pd.DataFrame, new_rows: pd.DataFrame, accuracy: dict) -> None:
        all_rows = pd.concat([training_rows, new_rows], ignore_index=True)
        final_pipeline = train(all_rows)

        current = self.serving
        info = dict(current.info, model_version=RETRAINED)
        if accuracy["measured"]:
            info.update(band_percent=accuracy["band_percent"],
                        measured_on="uploaded data (before retraining)",
                        rows=accuracy["rows"])

        # Back up the current model and its data before changing anything on disk.
        joblib.dump(current.pipeline, self.paths.previous_model, compress=3)
        _write_json(self.paths.previous_model_info, dict(current.info, model_version=current.version))
        shutil.copyfile(self.paths.training_data, self.paths.previous_training_data)

        joblib.dump(final_pipeline, self.paths.current_model, compress=3)
        _write_json(self.paths.model_info, info)
        all_rows.to_csv(self.paths.training_data, index=False)

        with self._swap_lock:
            self._serving = ServingModel(final_pipeline, RETRAINED, info)
        del current  # let the old model's memory be freed; its backup is on disk
        reference_data.load(self.paths.training_data)  # new markets become valid

    # ---------- rollback ----------

    def rollback(self) -> ServingModel:
        if not self._retrain_lock.acquire(blocking=False):
            raise RetrainBusyError("A retrain is running. Try again when it has finished.")
        try:
            return self._rollback()
        finally:
            self._retrain_lock.release()

    def _rollback(self) -> ServingModel:
        previous = self._load_previous_from_disk()
        if previous is None:
            raise NoBackupError("There is no previous model to roll back to.")

        # Restore the files so a restart also uses the previous model.
        if previous.version == ORIGINAL:
            self.paths.current_model.unlink(missing_ok=True)
        else:
            joblib.dump(previous.pipeline, self.paths.current_model, compress=3)
        _write_json(self.paths.model_info, previous.info)
        if self.paths.previous_training_data.exists():
            shutil.move(self.paths.previous_training_data, self.paths.training_data)
        self.paths.previous_model.unlink(missing_ok=True)
        self.paths.previous_model_info.unlink(missing_ok=True)

        with self._swap_lock:
            self._serving = previous
        reference_data.load(self.paths.training_data)
        return previous

    # ---------- loading ----------

    def _load_serving_model(self) -> ServingModel:
        """Use the retrained model if there is one, otherwise the notebook's original."""
        info = _read_json(self.paths.model_info)
        if self.paths.current_model.exists():
            return ServingModel(joblib.load(self.paths.current_model), RETRAINED, info)
        return ServingModel(joblib.load(self.paths.original_model), ORIGINAL, info)

    def _load_previous_from_disk(self) -> ServingModel | None:
        if not self.paths.previous_model.exists():
            return None
        info = _read_json(self.paths.previous_model_info)
        version = info.get("model_version", ORIGINAL)
        return ServingModel(joblib.load(self.paths.previous_model), version, info)


def split_check_set(rows: pd.DataFrame) -> CheckSplit:
    """Keep the newest month aside as the check set; train on the earlier months.

    With only one month, or too few rows, use a random 20% instead.
    """
    period = rows["year"] * 100 + rows["month"]  # e.g. 202608 = August 2026
    latest = period.max()
    if period.nunique() > 1 and len(rows) >= MIN_ROWS_FOR_CHECKS:
        description = f"latest month in the upload ({latest % 100:02d}/{latest // 100})"
        return CheckSplit(rows[period < latest], rows[period == latest], description)

    check_rows = rows.sample(frac=0.2, random_state=RANDOM_STATE)
    if check_rows.empty:  # a tiny upload: check on the single row we have
        check_rows = rows
    return CheckSplit(rows.drop(check_rows.index), check_rows, "random 20% of the upload")


def _decision_message(accepted: bool, current_mse: float, candidate_mse: float) -> str:
    if accepted:
        return (f"New model accepted: it was at least as good on the newest prices "
                f"({candidate_mse:.4f} vs {current_mse:.4f}).")
    return (f"New model rejected: it was worse on the newest prices "
            f"({candidate_mse:.4f} vs {current_mse:.4f}). Check the uploaded file.")


def _pattern_message(pattern: float) -> str:
    return (f"New model rejected: the prices in your file don't follow the usual pattern of "
            f"cheap and expensive foods (score {pattern:.2f}; real prices score about 0.95, and at "
            f"least {MIN_PRICE_PATTERN_MATCH} is needed). The prices may be shuffled or in the "
            f"wrong rows. Check the uploaded file.")


def _reasons_text(dropped: Counter) -> str:
    return "Dropped: " + "; ".join(f"{count} rows ({reason})" for reason, count in dropped.items()) + "."


def _read_json(path) -> dict:
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def _write_json(path, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)
