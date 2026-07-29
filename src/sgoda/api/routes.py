from fastapi import APIRouter

from sgoda.core.config import settings

router = APIRouter()


@router.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }


@router.get("/version", tags=["system"])
def version() -> dict[str, str]:
    return {
        "project": settings.project_code,
        "version": settings.app_version,
    }
