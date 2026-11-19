"""Measure peak memory (RAM) of the API during one retrain.

Render's free plan has 512 MB of RAM. This runs a real retrain with
data/new_data.csv on a temporary copy of the model and data folders and samples
the process's memory every 50 ms.

Run from the API folder:  python tools/measure_retrain_memory.py
"""

import shutil
import sys
import tempfile
import threading
import time
from pathlib import Path

import pandas as pd
import psutil

API_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(API_DIR))

from config import Paths  # noqa: E402
from model_service import ModelService  # noqa: E402

MB = 1024 * 1024


class PeakMemory:
    """Samples this process's memory in a background thread and keeps the highest value."""

    def __init__(self) -> None:
        self.process = psutil.Process()
        self.peak = 0
        self._running = True
        self._thread = threading.Thread(target=self._sample, daemon=True)

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, *_):
        self._running = False
        self._thread.join()

    def _sample(self) -> None:
        while self._running:
            self.peak = max(self.peak, self.process.memory_info().rss)
            time.sleep(0.05)


def current_mb() -> float:
    return psutil.Process().memory_info().rss / MB


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        shutil.copytree(API_DIR / "model", root / "model",
                        ignore=shutil.ignore_patterns("current_model.joblib", "previous_*"))
        shutil.copy(API_DIR / "best_model.pkl", root)
        (root / "data").mkdir()
        shutil.copy(API_DIR / "data" / "training_data.csv", root / "data")
        new_rows = pd.read_csv(API_DIR / "data" / "new_data.csv")

        service = ModelService(Paths(root=root))
        print(f"After startup (one model loaded): {current_mb():.0f} MB")

        with PeakMemory() as memory:
            result = service.retrain(new_rows)

        print(f"Retrain accepted: {result['accepted']}")
        print(f"After retrain (backup on disk only): {current_mb():.0f} MB")
        print(f"Peak during retrain: {memory.peak / MB:.0f} MB")


if __name__ == "__main__":
    main()
