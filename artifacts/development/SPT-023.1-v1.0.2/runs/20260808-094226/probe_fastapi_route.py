import importlib
module = importlib.import_module("sgoda.kernel.application")
app = getattr(module, "application")
paths = {getattr(route, "path", "") for route in app.routes}
target = "/api/spt0231/health"
if target not in paths:
    raise SystemExit("ROUTE_NOT_REGISTERED")
print("SPT0231_ROUTE_REGISTERED")