# Maths Summative: Rwanda Food Price Predictor (Flutter app)

A one-page app that sends 8 inputs to the API's `/predict` endpoint and shows the
predicted retail price (RWF per kg) with its likely range.

## Run it

1. Set your API address in `lib/config/api_config.dart` (`baseUrl`).
2. Start an Android emulator, an iOS simulator, or connect a phone, then:

```bash
flutter pub get
flutter run
```

In Chrome, use port 5000, which the API's CORS settings allow:

```bash
flutter run -d chrome --web-port 5000
```

## Features

- 8 labelled text fields in three sections (When, Where, What), a **Predict** button and
  one display area for the price ticket or the errors.
- Market and commodity suggestions while typing. Picking a market (or typing its exact
  name) fills in Province, District, Latitude and Longitude.
- **Use my location** finds the nearest market and fills in its details.
- Short, plain error messages under each field and in the display area.

The market and commodity lists in `assets/` are made by `summative/tools/generate_markets.py`
(at the repository root) from the training data.

## Fake location on the Android emulator

1. Open the emulator's **⋯ (Extended controls) → Location**.
2. Enter latitude `-2.596` and longitude `29.739` (Huye), then **Set location**.
3. Tap **Use my location** in the app: it fills in **Butare**, 0.5 km away.

Or from a terminal: `adb emu geo fix 29.739 -2.596` (longitude first).

## Project structure

| Folder | What it holds |
|---|---|
| `lib/config/` | API address, endpoint path and timeout |
| `lib/theme/` | Design tokens: colours, sizes, fonts |
| `lib/models/` | The 8 inputs, the form state, markets and the prediction result |
| `lib/utils/` | Validation, name search, distance (haversine) and formatting |
| `lib/services/` | The API call, the market list and the location lookup |
| `lib/widgets/` | Header, fields, suggestion list, buttons, display area, price ticket |
| `lib/screens/` | The prediction page |
| `test/` | Widget tests and logic tests |
