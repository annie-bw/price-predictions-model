# Maths Summative: Rwanda Food Price Predictor (Flutter app)

A one-page app that sends 8 inputs to the API's `/predict` endpoint and shows the
predicted retail price (RWF per kg) with its likely range.

## Run it

The app already points at the deployed API (`baseUrl` in `lib/config/api_config.dart`).
Start an Android emulator, an iOS simulator, or connect a phone, then:

```bash
flutter pub get
flutter run
```

For a quick check in Chrome (not for the demo), use port 5000, which the API's CORS
settings allow:

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

The market and commodity lists in `assets/` are made from the training data by
`summative/tools/generate_markets.py`.

## Fake location on the Android emulator

1. Open the emulator's **⋯ (Extended controls) → Location**.
2. Enter latitude `-2.596` and longitude `29.739` (Huye), then **Set location**.
3. Tap **Use my location** in the app: it fills in **Butare**, 0.5 km away.

Or from a terminal: `adb emu geo fix 29.739 -2.596` (longitude first).

## Project structure

| File | What it does |
|---|---|
| `lib/main.dart` | Starts the app: loads the market list, then shows the prediction page. |
| `lib/config/api_config.dart` | The API address, the `/predict` path and the 90-second timeout. |
| `lib/theme/app_theme.dart` | Design tokens: colours, sizes and fonts. |
| `lib/models/input_field_config.dart` | The 8 inputs: label, example, unit and order on the page. |
| `lib/models/prediction_form.dart` | The form's state: text fields, errors and auto-filled values. |
| `lib/models/market.dart` | A market with its province, district and coordinates. |
| `lib/models/prediction_result.dart` | The API's answer: price, low and high. |
| `lib/screens/prediction_page.dart` | The one page: puts the sections together and runs the prediction. |
| `lib/services/prediction_service.dart` | Calls `/predict` and turns errors into plain messages. |
| `lib/services/market_repository.dart` | Reads `assets/markets.json` and `assets/commodities.json`. |
| `lib/services/location_service.dart` | Asks for the phone's location. |
| `lib/utils/input_validator.dart` | Checks each field and writes the error message. |
| `lib/utils/name_search.dart` | Finds suggestions while typing (names that start with the text first). |
| `lib/utils/geo.dart` | Distance between two points and the nearest market. |
| `lib/utils/formatting.dart` | Formats prices and month names. |
| `lib/widgets/page_header.dart` | The title banner at the top. |
| `lib/widgets/section_header.dart` | The When / Where / What section titles. |
| `lib/widgets/labeled_field.dart` | A text field with its label, hint and error. |
| `lib/widgets/suggestion_field.dart` | A text field with a suggestion list under it. |
| `lib/widgets/location_controls.dart` | The **Use my location** button and its status. |
| `lib/widgets/predict_button.dart` | The **Predict** button with its loading state. |
| `lib/widgets/result_display.dart` | The display area: empty, loading, errors or the result. |
| `lib/widgets/price_ticket.dart` | The result card with the price and its range. |
| `lib/widgets/dashed_border.dart` | Draws the dashed borders in the display area and the price ticket. |
| `assets/` | Market and commodity lists for the suggestions. |
| `test/` | Widget tests and logic tests (30). |
| `android/`, `ios/` | Platform folders Flutter needs to build the app for phones. |
| `web/` | Only for checking the app in Chrome. |
