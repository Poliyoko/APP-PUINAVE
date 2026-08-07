from enum import Enum


class ComponentState(str, Enum):
    REGISTERED = "REGISTERED"
    INSTALLED = "INSTALLED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    RETIRED = "RETIRED"


ALLOWED_TRANSITIONS = {
    ComponentState.REGISTERED: {ComponentState.INSTALLED},
    ComponentState.INSTALLED: {ComponentState.ACTIVE, ComponentState.RETIRED},
    ComponentState.ACTIVE: {ComponentState.SUSPENDED, ComponentState.RETIRED},
    ComponentState.SUSPENDED: {ComponentState.ACTIVE, ComponentState.RETIRED},
    ComponentState.RETIRED: set(),
}