import json

import numpy as np
import pandas as pd
import pytest

from conftest import API_DIR, NEW_DATA, VALID_INPUT, csv_upload, make_client

APP_ASSETS = API_DIR.parent / "FlutterApp" / "assets"


# ---------- /predict ----------

def test_valid_predict_returns_a_price_inside_its_range(client):
    response = client.post("/predict", json=VALID_INPUT)

    assert response.status_code == 200
    body = response.json()
    assert body["predicted_price"] > 0
    assert body["low"] < body["predicted_price"] < body["high"]
    assert body["unit"] == "RWF/kg"
    assert body["range_coverage_percent"] == 80


def test_names_are_matched_ignoring_case_and_spaces(client):
    response = client.post("/predict", json={**VALID_INPUT, "admin1": "  southern province ",
                                             "commodity": "MAIZE"})
    assert response.status_code == 200


@pytest.mark.parametrize("change", [
    {"year": "abc"},       # wrong type
    {"month": 13},         # out of range
    {"latitude": -5.0},    # out of range
])
def test_wrong_type_or_out_of_range_returns_422(client, change):
    response = client.post("/predict", json={**VALID_INPUT, **change})
    assert response.status_code == 422


def test_missing_field_returns_422(client):
    incomplete = {key: value for key, value in VALID_INPUT.items() if key != "market"}
    response = client.post("/predict", json=incomplete)

    assert response.status_code == 422
    assert response.json()["detail"][0]["loc"] == ["body", "market"]


def test_unknown_market_returns_422_with_a_readable_message(client):
    response = client.post("/predict", json={**VALID_INPUT, "market": "Narnia"})

    assert response.status_code == 422
    assert response.json()["detail"][0]["msg"].startswith("Unknown market.")


def test_unknown_province_lists_the_valid_ones(client):
    response = client.post("/predict", json={**VALID_INPUT, "admin1": "Narnia"})

    message = response.json()["detail"][0]["msg"]
    assert message.startswith("Unknown province. Use one of: Eastern Province")


def test_health_shows_the_model_version(client):
    body = client.get("/").json()
    assert body["model_version"] == "original"
    assert body["band_percent"] > 0


def test_reference_lists_match_the_lists_built_into_the_app(client):
    body = client.get("/reference").json()

    assert body["markets"] == json.loads((APP_ASSETS / "markets.json").read_text("utf-8"))
    assert body["commodities"] == json.loads((APP_ASSETS / "commodities.json").read_text("utf-8"))


# ---------- /retrain and /rollback ----------

@pytest.fixture(scope="module")
def retrained(tmp_path_factory):
    """One accepted retrain with the real 2026 data, shared by the tests below."""
    client = make_client(tmp_path_factory.mktemp("retrained"))
    response = client.post("/retrain", files=csv_upload(pd.read_csv(NEW_DATA)))
    return client, response


def test_retrain_with_good_data_is_accepted(retrained):
    client, response = retrained

    assert response.status_code == 200
    body = response.json()
    assert body["accepted"] is True
    assert body["candidate_model_mse"] <= body["current_model_mse"]
    assert body["check_set"].startswith("latest month")
    assert body["model_version"] == "retrained"


def test_retrain_reports_the_error_on_new_data_before_retraining(retrained):
    _, response = retrained
    accuracy = response.json()["accuracy_on_new_data"]

    assert accuracy["measured"] is True
    assert accuracy["typical_error_percent"] > 0
    assert accuracy["band_percent"] > 0
    assert accuracy["message"].startswith("Before retraining, the model was typically")


def test_predict_still_works_after_retraining(retrained):
    client, _ = retrained
    response = client.post("/predict", json=VALID_INPUT)

    assert response.status_code == 200
    assert response.json()["predicted_price"] > 0


def test_a_new_commodity_can_be_predicted_after_retraining(client):
    # A made-up commodity (not in the real data) with the same markets and months as
    # Maize, at about 1,800 RWF/kg, stands in for a food that is new to the markets.
    rows = pd.read_csv(NEW_DATA)
    new_food = rows[rows["commodity"] == "Maize"].copy()
    new_food["commodity"] = "Test commodity"
    new_food["price"] = 1800 * np.random.default_rng(1).uniform(0.9, 1.1, len(new_food))
    new_input = dict(VALID_INPUT, commodity="test commodity")

    assert client.post("/predict", json=new_input).status_code == 422  # unknown before

    response = client.post("/retrain", files=csv_upload(pd.concat([rows, new_food])))

    assert response.json()["accepted"] is True
    after = client.post("/predict", json=new_input)
    assert after.status_code == 200
    assert 1200 < after.json()["predicted_price"] < 2700
    assert "Test commodity" in client.get("/reference").json()["commodities"]  # app suggests it


def test_retrain_with_shuffled_prices_is_rejected_and_old_model_keeps_serving(client):
    rows = pd.read_csv(NEW_DATA)
    rows["price"] = np.random.default_rng(42).permutation(rows["price"].to_numpy())
    price_before = client.post("/predict", json=VALID_INPUT).json()["predicted_price"]

    response = client.post("/retrain", files=csv_upload(rows))

    assert response.status_code == 200
    body = response.json()
    assert body["accepted"] is False
    assert body["message"].startswith("New model rejected")
    assert body["price_pattern_match"] < 0.7
    assert client.get("/").json()["model_version"] == "original"
    assert client.post("/predict", json=VALID_INPUT).json()["predicted_price"] == price_before


def test_wrong_prices_that_keep_the_pattern_are_caught_by_the_newest_month_check(client):
    """Earlier months typed 3x too big (below the 10x cleaning rule), latest month real.

    The pattern still looks normal, but the candidate learns the wrong prices and is
    worse on the real latest month, so the newest-month comparison rejects it.
    """
    rows = pd.read_csv(NEW_DATA)
    period = rows["year"] * 100 + rows["month"]
    rows.loc[period < period.max(), "price"] *= 3

    body = client.post("/retrain", files=csv_upload(rows)).json()

    assert body["price_pattern_match"] >= 0.7
    assert body["accepted"] is False
    assert body["candidate_model_mse"] > body["current_model_mse"]
    assert client.get("/").json()["model_version"] == "original"


def test_a_real_price_rise_is_not_rejected_as_bad_data(client):
    """If every price doubles, cheap foods are still cheap and expensive ones expensive."""
    rows = pd.read_csv(NEW_DATA)
    rows["price"] *= 2

    body = client.post("/retrain", files=csv_upload(rows)).json()

    assert body["price_pattern_match"] > 0.9
    assert body["accepted"] is True


def test_csv_with_missing_columns_returns_400_and_old_model_still_predicts(client):
    rows = pd.read_csv(NEW_DATA).drop(columns=["price", "market"])

    response = client.post("/retrain", files=csv_upload(rows))

    assert response.status_code == 400
    assert "missing these columns" in response.json()["detail"]
    assert client.post("/predict", json=VALID_INPUT).status_code == 200


def test_csv_with_no_valid_rows_returns_400(client):
    rows = pd.read_csv(NEW_DATA).head(5).assign(price=-1)

    response = client.post("/retrain", files=csv_upload(rows))

    assert response.status_code == 400
    assert "No valid rows" in response.json()["detail"]


def test_rollback_after_a_retrain_returns_200(retrained):
    client, _ = retrained

    response = client.post("/rollback")

    assert response.status_code == 200
    assert response.json()["model_version"] == "original"
    assert client.post("/predict", json=VALID_INPUT).status_code == 200


def test_rollback_without_a_backup_returns_400(client):
    assert client.post("/rollback").status_code == 400
