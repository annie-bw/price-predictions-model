# Predicting Retail Food Prices in Rwandan Markets

## Mission and problem

My mission is to use technology to solve Africa's agricultural challenges by developing practical digital solutions that increase productivity, improve market access, create employment opportunities for youth, and strengthen food security for future generations.

Rwandan farmers and small traders rarely know what a crop will sell for before they take it to market.
This project predicts the retail price (RWF per kg) of a food in a given market and month,
so they can decide when and where to sell, and NGOs can spot markets where food is getting too expensive.

## Dataset

- **Name:** Rwanda – Food Prices (World Food Programme)
- **Source:** Humanitarian Data Exchange (HDX): https://data.humdata.org/dataset/wfp-food-prices-for-rwanda, Rwanda food-prices.csv
- **Collected by:** WFP, MINAGRI and FAO (GIEWS/FPMA), updated every month.
- **Description:** monthly food prices from Rwandan markets, about 158,000 rows and
  16 columns (2000–2026), covering 109 markets in all 5 provinces and 65 commodities.
  It mixes numeric columns (latitude, longitude, price) and categorical columns (province,
  district, market, commodity, unit, price type), plus a date.
- **Target:** `price`, the retail price in Rwandan francs per kg (a regression problem).
  The model uses retail prices of foods sold per kg only.

## Public API (Swagger UI)

https://food-price-api-w69y.onrender.com/docs

The free Render service sleeps after 15 minutes without traffic, so the first request can
take up to a minute.

## Video demo

YouTube: *(https://studio.youtube.com/channel/UCuyCEHB8JiAktevuChL43bw/videos/upload?filter=%5B%5D&sort=%7B%22columnType%22%3A%22date%22%2C%22sortOrder%22%3A%22DESCENDING%22%7D)*

## Run the mobile app

You need [Flutter](https://docs.flutter.dev/get-started/install) (Dart 3.13 or newer) and
an Android emulator, an iOS simulator or a phone with USB debugging on.

1. Clone the repository:
   ```bash
   git clone https://github.com/annie-bw/price-predictions-model.git
   ```
2. Go to the app folder:
   ```bash
   cd price-predictions-model/summative/FlutterApp
   ```
3. Install the packages:
   ```bash
   flutter pub get
   ```
4. Start an emulator (or plug in a phone) and check that Flutter sees it:
   ```bash
   flutter devices
   ```
5. Run the app:
   ```bash
   flutter run
   ```
6. Fill in the 8 fields (or pick a market from the suggestions to fill the location for you)
   and press **Predict**. The app calls the deployed API, so no local server is needed.

---

## The model

`summative/linear_regression/multivariate.ipynb` compares four scikit-learn models on the
same test set. The model learns the log of the price, so the MSE below is on log prices.

| Model | Train MSE | Test MSE | Typical error |
|---|---|---|---|
| **RandomForestRegressor** | 0.0107 | **0.0207** | 15.5% |
| DecisionTreeRegressor | 0.0091 | 0.0265 | 17.7% |
| LinearRegression (closed form) | 0.0827 | 0.0828 | 33.3% |
| SGDRegressor (gradient descent) | 0.0830 | 0.0829 | 33.4% |

The **Random Forest** has the lowest test MSE, so it is saved (with its preprocessing, as a
scikit-learn Pipeline) and served by the API as `summative/API/best_model.pkl`.

The model uses 8 inputs: `year`, `month`, `latitude`, `longitude`, `admin1` (province),
`admin2` (district), `market` and `commodity`.

## Repository structure

```
README.md                  this file
render.yaml                Render settings for the API (root directory summative/API)
summative/
├── pyproject.toml         Python dependencies, managed with uv
├── uv.lock                exact versions of every package
├── .python-version        Python 3.13
├── linear_regression/
│   └── multivariate.ipynb the notebook: data, charts, the 4 models and the saved best model
├── API/                   FastAPI service, see the API README for every file
│   ├── prediction.py      the app and its routes
│   ├── requirements.txt   what Render installs (exported from uv.lock)
│   └── best_model.pkl     the Random Forest saved by the notebook
├── FlutterApp/            one-page mobile app, see the app README for every file
└── tools/
    └── generate_markets.py  builds the market and commodity lists built into the app
```

Running the notebook downloads the raw data from HDX and writes `data/training_data.csv`,
`data/new_data.csv` and `best_model.joblib` next to it. Those outputs are not committed:
the API keeps its own copies (`API/best_model.pkl` and `API/data/`).

More detail: [API README](summative/API/README.md) · [app README](summative/FlutterApp/README.md)

## Run the API locally

With [uv](https://docs.astral.sh/uv/):

```bash
cd summative
uv sync                                   # creates .venv from uv.lock (with pytest)
cd API
uv run uvicorn prediction:app --reload    # then open http://127.0.0.1:8000/docs
uv run pytest                             # run the tests
```

## Retraining with new data

`POST /retrain` takes a CSV with the 8 input columns plus `price` (for example
`summative/API/data/new_data.csv`, the 2026 prices the model has never seen). Uploading the
file starts the retraining: the rows are checked and cleaned, a new Random Forest is trained
on the original data plus the new rows, and it replaces the current model only if it
predicts the newest month at least as well. `/predict` then uses it straight away, with no
redeploy. See the [API README](summative/API/README.md) for the details.
