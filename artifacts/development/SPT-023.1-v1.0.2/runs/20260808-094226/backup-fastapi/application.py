"""FÃ¡brica principal de la aplicaciÃ³n SGODA-PUINAVE."""

from fastapi import FastAPI
from sgoda.api.spt022_routes import router as spt022_router

from sgoda.api.kernel_routes import (
    router as kernel_router,
)
from sgoda.api.routes import (
    router as foundation_router,
)
from sgoda.kernel.metadata import (
    PLATFORM_VERSION,
    PROJECT_NAME,
)
from sgoda.kernel.modules import (
    register_platform_modules,
)
from sgoda.kernel.registry import module_registry


def create_application() -> FastAPI:
    """Construye y configura la aplicaciÃ³n."""

    register_platform_modules(module_registry)

    application = FastAPI(
        title=PROJECT_NAME,
        version=PLATFORM_VERSION,
        description=(
            "Plataforma digital para la "
            "preservaciÃ³n y enseÃ±anza "
            "de la lengua Puinave."
        ),
    )

    application.include_router(
        foundation_router,
    )
    application.include_router(
        kernel_router,
    )

    application.include_router(
        spt022_router,
    )
    application.state.module_registry = (
        module_registry
    )
    application.state.kernel_status = (
        "operational"
    )

    return application
