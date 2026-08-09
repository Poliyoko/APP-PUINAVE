import json
from sgoda.api.spt0231_routes import router

routes = [
    {
        "path": getattr(route, "path", ""),
        "methods": sorted(getattr(route, "methods", set()) or set()),
    }
    for route in router.routes
]

print(json.dumps({
    "prefix": router.prefix,
    "count": len(routes),
    "routes": routes,
}, ensure_ascii=False))