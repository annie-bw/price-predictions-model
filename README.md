# Predicting Retail Food Prices in Rwandan Markets

## Mission

My mission is to use technology to solve Africa's agricultural challenges by developing
practical digital solutions that increase productivity, improve market access, create
employment opportunities for youth, and strengthen food security for future generations.

## Dataset

- **Name:** Rwanda – Food Prices (World Food Programme)
- **Source:** Humanitarian Data Exchange (HDX): https://data.humdata.org/dataset/wfp-food-prices-for-rwanda
- **Collected by:** WFP, MINAGRI and FAO (GIEWS/FPMA), updated every month.
- **Description:** monthly food prices from Rwandan markets, about 158,000 rows and
  16 columns (2000–2026), covering 109 markets in all 5 provinces and 65 commodities.
  It mixes numeric columns (latitude, longitude, price) and categorical columns (province,
  district, market, commodity, unit, price type), plus a date.
- **Target:** `price`, the retail price in Rwandan francs per kg (a continuous number, so
  this is a regression problem). The model uses retail prices of foods sold per kg only.

## Use case

Farmers, small traders and food-security organisations in Rwanda need to know what a crop
will sell for **before** they take it to market. The model predicts the **retail price
(RWF per kg)** of a food in a given market and month.

- **Farmers** can decide *when* and *where* to sell their harvest.
- **Traders** can plan what to buy and where to resell it.
- **NGOs and cooperatives** can spot markets where food is becoming too expensive.

## Links

| What | Link |
|---|---|
| Public API (Swagger UI) | https://food-price-api-w69y.onrender.com/docs |
| Video demo (YouTube) | *add the link here* |

The free Render service sleeps after 15 minutes without traffic, so the first request can
take up to a minute.

## The model

`linear_regression/multivariate.ipynb` compares four scikit-learn models on the same test
set. The model learns the log of the price, so the MSE below is on log prices.

| Model | Train MSE | Test MSE | Typical error |
|---|---|---|---|
| **RandomForestRegressor** | 0.0107 | **0.0207** | 15.5% |
| DecisionTreeRegressor | 0.0091 | 0.0265 | 17.7% |
| LinearRegression (closed form) | 0.0827 | 0.0828 | 33.3% |
| SGDRegressor (gradient descent) | 0.0830 | 0.0829 | 33.4% |

The **Random Forest** has the lowest test MSE, so it is saved (with its preprocessing, as a
scikit-learn Pipeline) to `best_model.joblib` and served by the API.

The model uses 8 inputs: `year`, `month`, `latitude`, `longitude`, `admin1` (province),
`admin2` (district), `market` and `commodity`.

## Repository structure

| Folder | What it holds |
|---|---|
| `linear_regression/` | The notebook, the training data, the 2026 "new data" and the saved model |
| `API/` | FastAPI service: `/predict`, `/retrain`, `/rollback` and `/docs` ([API README](API/README.md)) |
| `FlutterApp/` | One-page Flutter mobile app that calls `/predict` ([app README](FlutterApp/README.md)) |
| `tools/` | Script that builds the app's market and commodity lists from the training data |
| `render.yaml` | Render settings for deploying the API |

## Run the mobile app

You need Flutter and an Android emulator, an iOS simulator or a phone.

```bash
cd FlutterApp
flutter pub get
flutter run
```

The app already points at the deployed API (`lib/config/api_config.dart`).

## Run the API locally

```bash
cd API
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
uvicorn main:app --reload        # then open http://127.0.0.1:8000/docs
pytest                           # run the tests
```

## Retraining with new data

`POST /retrain` takes a CSV with the 8 input columns plus `price` (for example
`API/data/new_data.csv`, the 2026 prices the model has never seen). Uploading the file
starts the retraining: the rows are checked and cleaned, a new Random Forest is trained on
the original data plus the new rows, and it replaces the current model only if it predicts
the newest month at least as well. `/predict` then uses it straight away, with no redeploy.
See the [API README](API/README.md) for the details.
