from fastapi import FastAPI
from sgoda.api.spt0231_routes import router

app = FastAPI()
app.include_router(router)

paths = {getattr(route, "path", "") for route in app.routes}

if "/api/spt0231/health" not in paths:
    raise SystemExit("SPT0231_ROUTE_NOT_REGISTERED")

if "/api/spt0231/detect" not in paths:
    raise SystemExit("SPT0231_DETECT_NOT_REGISTERED")

print("SPT0231_ROUTER_ISOLATED_OK")