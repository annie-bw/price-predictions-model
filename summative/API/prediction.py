"""The FastAPI app: CORS settings and the routes. The ML work is done by ModelService."""

import io

import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from cleaning import UploadError
from config import Paths, allowed_origins
from model_service import ModelService, NoBackupError, RetrainBusyError, TrainingError
from schemas import (
    HealthResponse,
    PredictionRequest,
    PredictionResponse,
    ReferenceResponse,
    RetrainResponse,
    RollbackResponse,
)
from reference_data import reference_data


def create_app(paths: Paths = Paths()) -> FastAPI:
    """Build the app. Tests pass their own Paths so they never touch the real files."""
    app = FastAPI(
        title="Rwanda Food Price Predictor",
        description="Predicts the retail price (RWF per kg) of a food in a Rwandan market and month.",
        version="1.0.0",
    )

    # CORS decides which *websites* may call this API from a browser.
    # - Allowed: only the origins in ALLOWED_ORIGINS (by default our Render URL and
    #   http://localhost:5000, where `flutter run -d chrome --web-port 5000` serves the app).
    #   We list them instead of using "*" so other websites can't use the API from their pages.
    # - Methods: only GET and POST, the only ones our routes use.
    # - Headers: only Content-Type, which is all the app sends (JSON or a file upload).
    # - Credentials: off, because the API uses no cookies or logins.
    # A mobile app is not a browser, so CORS doesn't restrict it: the phone app can
    # always call the API. CORS only controls which websites can call it from a browser.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins(),
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
        allow_credentials=False,
    )

    # Loaded once at startup, not on every request.
    service = ModelService(paths)

    @app.get("/", response_model=HealthResponse)
    def health():
        serving = service.serving
        return HealthResponse(
            status="ok",
            message="The price API is running. See /docs to try it.",
            model_version=serving.version,
            band_percent=serving.band_percent,
        )

    @app.get("/reference", response_model=ReferenceResponse)
    def reference():
        """The markets and commodities the current model knows. The app loads these
        at startup, so names added by a retrain appear in its suggestions."""
        return ReferenceResponse(markets=reference_data.markets,
                                 commodities=reference_data.commodities)

    @app.post("/predict", response_model=PredictionResponse)
    def predict(request: PredictionRequest):
        return PredictionResponse(**service.predict(request.model_dump()))

    @app.post("/retrain", response_model=RetrainResponse)
    def retrain(file: UploadFile = File(description="CSV with the 8 input columns plus price.")):
        uploaded_rows = _read_csv(file)
        try:
            return service.retrain(uploaded_rows)
        except UploadError as error:
            raise HTTPException(status_code=400, detail=str(error))
        except RetrainBusyError as error:
            raise HTTPException(status_code=409, detail=str(error))
        except TrainingError as error:
            raise HTTPException(status_code=500, detail=str(error))

    @app.post("/rollback", response_model=RollbackResponse)
    def rollback():
        try:
            restored = service.rollback()
        except NoBackupError as error:
            raise HTTPException(status_code=400, detail=str(error))
        except RetrainBusyError as error:
            raise HTTPException(status_code=409, detail=str(error))
        return RollbackResponse(
            message=f"Rolled back to the previous model ({restored.version}).",
            model_version=restored.version,
            band_percent=restored.band_percent,
        )

    return app


def _read_csv(file: UploadFile) -> pd.DataFrame:
    try:
        return pd.read_csv(io.BytesIO(file.file.read()))
    except (pd.errors.ParserError, pd.errors.EmptyDataError, UnicodeDecodeError):
        raise HTTPException(status_code=400, detail="The file could not be read as a CSV.")


app = create_app()
