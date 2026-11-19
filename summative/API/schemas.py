"""Request and response models. Pydantic checks types and ranges; FastAPI turns
any problem into a 422 response that lists every field that is wrong."""

from pydantic import BaseModel, Field, ValidationInfo, field_validator
from pydantic_core import PydanticCustomError

from config import NUMERIC_RANGES, RANGE_COVERAGE_PERCENT
from reference_data import reference_data


def _numeric_field(name: str, description: str, example: float):
    low, high = NUMERIC_RANGES[name]
    return Field(ge=low, le=high, description=f"{description} ({low} to {high}).", examples=[example])


class PredictionRequest(BaseModel):
    year: int = _numeric_field("year", "Year of the price", 2026)
    month: int = _numeric_field("month", "Month of the price, 1 = January", 6)
    latitude: float = _numeric_field("latitude", "Market latitude in degrees", -2.6)
    longitude: float = _numeric_field("longitude", "Market longitude in degrees", 29.74)
    admin1: str = Field(description="Province, e.g. Southern Province.", examples=["Southern Province"])
    admin2: str = Field(description="District, e.g. Huye.", examples=["Huye"])
    market: str = Field(description="Market name, e.g. Butare.", examples=["Butare"])
    commodity: str = Field(description="A food sold per kg, e.g. Maize.", examples=["Maize"])

    @field_validator("admin1", "admin2", "market", "commodity")
    @classmethod
    def must_be_known_name(cls, value: str, info: ValidationInfo) -> str:
        """Accept any case and extra spaces, but send the official spelling to the model."""
        canonical = reference_data.canonical(info.field_name, value)
        if canonical is None:
            # PydanticCustomError keeps the message as written (no "Value error, " prefix).
            message = reference_data.unknown_name_message(info.field_name, value)
            raise PydanticCustomError("unknown_name", message)
        return canonical


class PredictionResponse(BaseModel):
    predicted_price: float = Field(description="Predicted retail price in RWF per kg.", examples=[486.2])
    unit: str = Field(default="RWF/kg", examples=["RWF/kg"])
    low: float = Field(description="Low end of the likely price range.", examples=[385.0])
    high: float = Field(description="High end of the likely price range.", examples=[615.0])
    range_coverage_percent: int = Field(
        default=RANGE_COVERAGE_PERCENT,
        description="How many real prices out of 100 fall between low and high.",
    )


class AccuracyOnNewData(BaseModel):
    """How far off the model in use was on the uploaded rows, before retraining on them."""

    measured: bool
    rows: int
    typical_error_percent: float | None = None
    band_percent: float | None = None
    message: str


class RetrainResponse(BaseModel):
    accepted: bool
    message: str
    rows_received: int
    rows_used: int
    rows_dropped: int
    dropped_reasons: dict[str, int]
    price_pattern_match: float | None = Field(
        default=None,
        description="How well the uploaded prices follow the usual pattern of cheap and expensive "
                    "foods (correlation of log prices; real data is about 0.95). Below 0.7 the "
                    "upload is rejected. Empty when there were fewer than 50 rows.")
    # The check-set fields are empty when the upload was rejected before training.
    check_set: str | None = Field(default=None, description="Rows kept aside to compare the two models.")
    check_set_rows: int | None = None
    current_model_mse: float | None = Field(
        default=None, description="MSE (log) of the model in use on the check set.")
    candidate_model_mse: float | None = Field(
        default=None, description="MSE (log) of the new model on the check set.")
    accuracy_on_new_data: AccuracyOnNewData
    model_version: str


class RollbackResponse(BaseModel):
    message: str
    model_version: str
    band_percent: float


class HealthResponse(BaseModel):
    status: str
    message: str
    model_version: str
    band_percent: float


class MarketInfo(BaseModel):
    market: str
    province: str
    district: str
    latitude: float
    longitude: float


class ReferenceResponse(BaseModel):
    """The names /predict accepts right now, for the app's suggestions and auto-fill."""

    markets: list[MarketInfo]
    commodities: list[str]
