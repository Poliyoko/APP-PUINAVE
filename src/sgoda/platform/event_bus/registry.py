from dataclasses import dataclass
from typing import Callable, Dict, Iterable, Tuple


class SubscriptionError(RuntimeError):
    pass


@dataclass(frozen=True)
class Subscription:
    name: str
    handler: Callable
    event_types: Tuple[str, ...]


class EventSubscriptionRegistry:
    def __init__(self) -> None:
        self._subscriptions: Dict[str, Subscription] = {}

    def subscribe(self, name: str, handler: Callable, event_types=()) -> Subscription:
        if not name or not name.strip():
            raise ValueError("subscriber name is required")
        if not callable(handler):
            raise ValueError("handler must be callable")
        if name in self._subscriptions:
            raise SubscriptionError(
                "subscriber already registered: {0}".format(name)
            )

        subscription = Subscription(
            name=name.strip(),
            handler=handler,
            event_types=tuple(sorted(set(event_types))),
        )
        self._subscriptions[subscription.name] = subscription
        return subscription

    def unsubscribe(self, name: str) -> None:
        self._subscriptions.pop(name, None)

    def matching(self, event_type: str) -> Iterable[Subscription]:
        return tuple(
            subscription
            for subscription in self._subscriptions.values()
            if not subscription.event_types
            or event_type in subscription.event_types
        )

    def subscriptions(self) -> Iterable[Subscription]:
        return tuple(self._subscriptions.values())