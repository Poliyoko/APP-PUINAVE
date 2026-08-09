import json
from fastapi import FastAPI
from sgoda.api.spt0231_routes import router

app = FastAPI()
app.include_router(router)

routes = []

for route in app.routes:
    path = getattr(route, "path", "")
    methods = sorted(getattr(route, "methods", set()) or set())

    if not path:
        continue

    if path.startswith("/openapi"):
        continue

    if path.startswith("/docs"):
        continue

    if path.startswith("/redoc"):
        continue

    routes.append({
        "path": path,
        "methods": methods,
    })

if not routes:
    raise SystemExit("SPT0231_NO_ROUTES_REGISTERED")

print(json.dumps({
    "status": "SPT0231_ROUTER_DYNAMIC_OK",
    "routes": routes,
}, ensure_ascii=False))