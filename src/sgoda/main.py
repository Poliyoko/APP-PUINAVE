from fastapi import FastAPI

from sgoda.api.routes import router
from sgoda.core.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Backend base del ecosistema SGODA-PUINAVE.",
)

app.include_router(router)
