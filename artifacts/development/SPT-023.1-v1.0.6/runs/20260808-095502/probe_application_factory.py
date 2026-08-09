import json
from sgoda.kernel.application import create_application

app = create_application()

paths = {
    getattr(route, "path", "")
    for route in app.routes
}

required = {
    "/api/spt0231/health",
    "/api/spt0231/detect",
}

missing = sorted(required - paths)

if missing:
    print(json.dumps({
        "status": "MISSING",
        "missing": missing,
    }))
    raise SystemExit(2)

print(json.dumps({
    "status": "CONFIRMED",
    "paths": sorted(required),
}))