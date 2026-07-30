from functools import lru_cache
import os

from pydantic import BaseModel


class Settings(BaseModel):
    project_code: str = "SGODA-PUINAVE"
    app_name: str = "SGODA-PUINAVE API"
    app_version: str = "0.1.0"
    environment: str = "development"
    host: str = "127.0.0.1"
    port: int = 8000


@lru_cache
def get_settings() -> Settings:
    return Settings(
        project_code=os.getenv("SGODA_PROJECT_CODE", "SGODA-PUINAVE"),
        app_name=os.getenv("SGODA_APP_NAME", "SGODA-PUINAVE API"),
        app_version=os.getenv("SGODA_APP_VERSION", "0.1.0"),
        environment=os.getenv("SGODA_ENVIRONMENT", "development"),
        host=os.getenv("SGODA_HOST", "127.0.0.1"),
        port=int(os.getenv("SGODA_PORT", "8000")),
    )


settings = get_settings()
