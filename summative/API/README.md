# Rwanda Food Price Predictor – API

A FastAPI service that predicts the retail price (RWF per kg) of a food in a Rwandan
market and month, using the Random Forest from `summative/linear_regression/multivariate.ipynb`
(saved here as `best_model.pkl`).

**Public Swagger UI:** https://food-price-api-w69y.onrender.com/docs

## Run it locally

Dependencies are managed with [uv](https://docs.astral.sh/uv/); `pyproject.toml` and
`uv.lock` are in the `summative/` folder (Python 3.13):

```bash
cd summative
uv sync
cd API
uv run uvicorn prediction:app --reload
```

`requirements.txt` is exported from `uv.lock` for Render
(`uv export --format requirements.txt --no-hashes --no-dev -o API/requirements.txt`).

Open http://127.0.0.1:8000/docs to try every route.

Run the tests:

```bash
uv run pytest
```

To use the Flutter app in Chrome against the local API, run it on the port CORS allows:

```bash
flutter run -d chrome --web-port 5000
```

## Deploy on Render

The easiest way is the Blueprint in `render.yaml` at the repository root: in Render choose
**New + → Blueprint**, pick the repository, and enter `ALLOWED_ORIGINS` when asked.
It sets up the same values as the table below, which you can also enter by hand
(**New + → Web Service**).

| Setting | Value |
|---|---|
| Root directory | `summative/API` |
| Build command | `pip install -r requirements.txt` |
| Start command | `uvicorn prediction:app --host 0.0.0.0 --port $PORT` |
| Environment variable `PYTHON_VERSION` | `3.13.2` |
| Environment variable `ALLOWED_ORIGINS` | `https://food-price-api-w69y.onrender.com,http://localhost:5000` |

## Routes

| Route | What it does |
|---|---|
| `GET /` | Health check: the model in use (`original` or `retrained`) and its price-range band. |
| `POST /predict` | Predicts a price from the 8 inputs and returns a likely range. |
| `GET /reference` | The markets (with province, district and coordinates) and commodities the current model knows. The app uses it for suggestions. |
| `POST /retrain` | Upload a CSV of new prices; retrains with a backup and a quality check. |
| `POST /rollback` | Puts the previous model back after a retrain. |
| `GET /docs` | Swagger UI. |

### `/predict`

```json
{"year": 2026, "month": 6, "latitude": -2.6, "longitude": 29.74,
 "admin1": "Southern Province", "admin2": "Huye", "market": "Butare", "commodity": "Maize"}
```

returns

```json
{"predicted_price": 494.7, "unit": "RWF/kg", "low": 390.8, "high": 626.3, "range_coverage_percent": 80}
```

Names are matched ignoring case and extra spaces, and unknown names return 422
with a readable message (for example *"Unknown province. Use one of: Eastern Province, …"*).

### The price range is measured on future prices

The model is typically about 15% off on the random test set, but **about 22% off on
genuinely new data** (the 2026 rows it never saw). The range uses the new-data number:
`band_percent` is the 80th percentile of `|ln(actual / predicted)|` on those rows,
so 8 out of 10 real prices fall between `low` and `high`.

`tools/measure_band.py` measured it once on `new_data.csv` (2,422 rows): **±26.6%**,
saved in `model/model_info.json`. An accepted `/retrain` updates it.

## How `/retrain` decides

Uploading the CSV (the 8 input columns plus `price`) starts the retrain:

1. **Check the rows.** Drop rows with missing or non-numeric values, `price <= 0`, or
   numbers out of range. No valid rows left → 400.
2. **Clean** with the notebook's rule: drop prices more than 10× above or below their
   commodity's median.
3. **Measure the current model on the new rows** (≥ 200 rows): its typical error and the
   80% band, e.g. *"Before retraining, the model was typically 22% off on your new data;
   8 in 10 prices were within ±27%."*
4. **Price pattern check** (≥ 50 rows): the prices must follow the usual pattern of cheap
   and expensive foods (see below). Otherwise the upload is rejected before training.
5. **Keep the newest month aside** as the check set and train a candidate on the original
   training data plus the earlier months. (One month or fewer than 200 rows: a random 20%.)
6. **Compare** the current model and the candidate on the check set (MSE on log prices).
   The candidate is accepted only if it is at least as good.
7. **If accepted:** refit on everything, back up the current model to
   `model/previous_model.joblib`, save the new one as `model/current_model.joblib`, add the
   rows to `data/training_data.csv` and update the band. `best_model.pkl` is never
   overwritten. `POST /rollback` restores the backup.

### The price pattern check

If a whole file has shuffled prices, the newest-month check set is shuffled too, so
comparing the two models on it can't catch the problem. So before training we check
that the prices look like real prices: the correlation between the uploaded log prices
and the current model's log predictions must be at least **0.7**
(`MIN_PRICE_PATTERN_MATCH` in `config.py`).

It compares *which* foods and markets are cheap or expensive, not the price level, so
real price rises are not mistaken for bad data:

| Upload (2026 rows) | Pattern score | Result |
|---|---|---|
| Real prices | 0.97 | passes |
| Meat 2.5× more expensive | 0.95 | passes |
| Every price 2× or 3× higher | 0.97 | passes |
| Half the prices shuffled | 0.49 | rejected |
| All prices shuffled | 0.01 | rejected |

**Known limitation – a uniform typo looks like a real price rise.** If *every* price in a
file is wrong by the same factor (for example all typed 2× too high, or entered in the
wrong unit), the pattern of cheap and expensive foods is unchanged, so this check can't
tell it apart from real inflation. Other checks cover part of this: prices more than 10×
off their commodity's median are dropped in step 2, and if only the earlier months are
wrong, the newest-month comparison rejects the candidate. But a file where every month,
including the newest, is off by the same moderate factor will be accepted. Check the
units and the scale of a file before uploading it, and use `POST /rollback` if needed.

### New commodities and markets

A CSV can bring a commodity or market the model has never seen.
The rows are not rejected for their name. If the retrain is accepted, the new model has
learned the new name and `/predict` accepts it straight away. Before that, it returns 422
("Unknown commodity…"), because the model would have no prices to learn from.
`test_a_new_commodity_can_be_predicted_after_retraining` checks this.

Give the new commodity rows in several months, so the model sees it in training and not
only in the newest month (which is kept aside as the check set). The app loads its
suggestions from `GET /reference` when it starts, so after an accepted retrain, the new name
also appears in the app's suggestions.

## Memory (Render free plan: 512 MB)

Measured locally while retraining with `new_data.csv`:

| Moment | Memory |
|---|---|
| After startup (one model loaded) | ~270 MB |
| Peak during a retrain | ~500 MB |
| After a retrain | ~310 MB |

Because of this, the backup model is kept **on disk only** and loaded back on rollback.
The peak comes from training itself (the serving model plus the new forest and about
138,000 rows); training on one CPU core instead of all of them only saves about 25 MB.
A retrain may therefore run out of memory on the free plan. `/predict` is not affected.

Note that Render's free plan has no persistent disk: a retrained model and the added
rows are lost when the service restarts, and it starts again from `best_model.pkl`.

## Files

| File | Job |
|---|---|
| `prediction.py` | The FastAPI app: CORS and the routes. No ML logic. Render starts this file. |
| `schemas.py` | Pydantic models: the types and ranges of the 8 inputs, and the shape of every response. They give the 422 errors and the examples in Swagger. |
| `model_service.py` | Loads the model, predicts, retrains, keeps the backup and rolls back. |
| `cleaning.py` | Checks and cleans uploaded CSV rows (missing values, ranges, the 10× rule). |
| `metrics.py` | Accuracy measures: log MSE, typical error, the price band, the price pattern. |
| `reference_data.py` | The known provinces, districts, markets and commodities, read from the training data: used to check names in `/predict` and returned by `/reference`. |
| `config.py` | File paths, input ranges, allowed CORS origins and the constants above. |
| `best_model.pkl` | The Random Forest pipeline saved by the notebook. Never overwritten. |
| `model/model_info.json` | The price band (±26.6%) and which model is in use. Retrained models are saved in this folder too. |
| `data/training_data.csv` | The rows the model was trained on. `/retrain` adds the new rows to it. |
| `data/new_data.csv` | 2026 prices the model never saw: the sample file to upload to `/retrain`. |
| `requirements.txt` | The packages Render installs, exported from `uv.lock`. |
| `tools/measure_band.py` | Measured the band on `new_data.csv` and wrote `model/model_info.json`. |
| `tests/conftest.py` | Test setup: runs the API on a temporary copy of the model and data. |
| `tests/test_api.py` | The pytest tests (21). |
