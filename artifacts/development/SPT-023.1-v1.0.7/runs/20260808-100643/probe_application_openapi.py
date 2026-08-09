import json
import fastapi
import starlette

from sgoda.kernel.application import create_application

app = create_application()
schema = app.openapi()
paths = schema.get("paths", {})

required = {
    "/api/spt0231/health": {"get"},
    "/api/spt0231/detect": {"post"},
}

missing = []
wrong_methods = []

for path, expected_methods in required.items():
    if path not in paths:
        missing.append(path)
        continue

    actual_methods = {
        str(method).lower()
        for method in paths[path].keys()
    }

    if not expected_methods.issubset(actual_methods):
        wrong_methods.append({
            "path": path,
            "expected": sorted(expected_methods),
            "actual": sorted(actual_methods),
        })

payload = {
    "status": (
        "CONFIRMED"
        if not missing and not wrong_methods
        else "FAILED"
    ),
    "fastapi_version": fastapi.__version__,
    "starlette_version": starlette.__version__,
    "required_paths": sorted(required.keys()),
    "openapi_paths": sorted(paths.keys()),
    "missing": missing,
    "wrong_methods": wrong_methods,
}

print(json.dumps(payload, ensure_ascii=False, sort_keys=True))

if missing or wrong_methods:
    raise SystemExit(2)