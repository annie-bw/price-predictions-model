"""Test setup: every test module gets its own copy of the model and data folders,
so retraining in a test never changes the real files."""

import shutil
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

API_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(API_DIR))

from config import Paths  # noqa: E402
from prediction import create_app  # noqa: E402

NEW_DATA = API_DIR / "data" / "new_data.csv"

VALID_INPUT = {
    "year": 2026,
    "month": 6,
    "latitude": -2.6,
    "longitude": 29.74,
    "admin1": "Southern Province",
    "admin2": "Huye",
    "market": "Butare",
    "commodity": "Maize",
}


def make_client(tmp_dir: Path) -> TestClient:
    shutil.copytree(API_DIR / "model", tmp_dir / "model",
                    ignore=shutil.ignore_patterns("current_model.joblib", "previous_*"))
    shutil.copy(API_DIR / "best_model.pkl", tmp_dir)
    (tmp_dir / "data").mkdir()
    shutil.copy(API_DIR / "data" / "training_data.csv", tmp_dir / "data")
    return TestClient(create_app(Paths(root=tmp_dir)))


@pytest.fixture
def client(tmp_path) -> TestClient:
    return make_client(tmp_path)


def csv_upload(rows) -> dict:
    """Turn a DataFrame into the `files` argument for a /retrain request."""
    return {"file": ("upload.csv", rows.to_csv(index=False), "text/csv")}
