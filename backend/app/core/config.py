from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All runtime configuration. Values come from env vars or backend/.env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://transit:transit@localhost:5433/transit"
    test_database_url: str = "postgresql+asyncpg://transit:transit@localhost:5433/transit_test"

    jwt_secret: str = "dev-secret-change-me-dev-secret-change-me"
    access_token_minutes: int = 30
    refresh_token_days: int = 7
    bcrypt_rounds: int = 12  # tests lower this for speed

    # College-local timezone: schedules ("07:30 departure") are interpreted in it.
    timezone: str = "Asia/Kolkata"

    qr_ttl_seconds: int = 30
    delay_threshold_min: int = 5
    capacity_warn_pct: int = 90
    delay_watch_interval_seconds: int = 60
    trip_generation_interval_seconds: int = 900
    # A trip still in progress after its service day is closed automatically once it has had no
    # start/stop activity for this long (covers drivers who forget to tap End).
    stale_trip_grace_hours: int = 3

    # Live tracking (GPS from the driver's phone).
    arrival_radius_m: int = 100  # a stop is auto-marked arrived inside this radius
    approach_radius_m: int = 2000  # riders of a stop are told when the bus is this close
    max_fix_accuracy_m: int = 100  # fixes less accurate than this are stored but never trigger anything
    arrival_lookahead_stops: int = 2  # auto-arrival considers only the next N unreached stops

    # Lets admins pass explicit timestamps (e.g. arrived_at) to simulate delays in demos.
    allow_simulation: bool = True
    enable_background_tasks: bool = True

    cors_origins: str = "*"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
