from typing import List, Optional, Tuple

from .models import DeadLetter, EventDelivery, InstitutionalEvent
from .registry import EventSubscriptionRegistry


class NoSubscriberError(RuntimeError):
    pass


class InstitutionalEventBus:
    def __init__(
        self,
        registry: Optional[EventSubscriptionRegistry] = None,
        max_attempts: int = 2,
    ) -> None:
        if max_attempts < 1:
            raise ValueError("max_attempts must be at least 1")

        self.registry = registry or EventSubscriptionRegistry()
        self.max_attempts = max_attempts
        self.history: List[EventDelivery] = []
        self.dead_letters: List[DeadLetter] = []

    def subscribe(self, name, handler, event_types=()):
        return self.registry.subscribe(name, handler, event_types)

    def publish(self, event: InstitutionalEvent) -> Tuple[EventDelivery, ...]:
        subscriptions = tuple(self.registry.matching(event.event_type))

        if not subscriptions:
            raise NoSubscriberError(
                "no subscriber available for event: {0}".format(
                    event.event_type
                )
            )

        deliveries = []

        for subscription in subscriptions:
            attempts = 0
            delivered = False
            error = ""

            while attempts < self.max_attempts and not delivered:
                attempts += 1

                try:
                    subscription.handler(event)
                    delivered = True
                except Exception as exc:
                    error = str(exc)

            delivery = EventDelivery(
                event_id=event.event_id,
                subscriber_name=subscription.name,
                delivered=delivered,
                attempts=attempts,
                error=error,
            )
            deliveries.append(delivery)
            self.history.append(delivery)

            if not delivered:
                self.dead_letters.append(
                    DeadLetter(
                        event=event,
                        subscriber_name=subscription.name,
                        attempts=attempts,
                        error=error,
                    )
                )

        return tuple(deliveries)

    def replay_dead_letters(self) -> Tuple[EventDelivery, ...]:
        pending = tuple(self.dead_letters)
        self.dead_letters.clear()
        results = []

        for dead_letter in pending:
            subscription = next(
                (
                    item
                    for item in self.registry.subscriptions()
                    if item.name == dead_letter.subscriber_name
                ),
                None,
            )

            if subscription is None:
                self.dead_letters.append(dead_letter)
                continue

            attempts = 0
            delivered = False
            error = ""

            while attempts < self.max_attempts and not delivered:
                attempts += 1

                try:
                    subscription.handler(dead_letter.event)
                    delivered = True
                except Exception as exc:
                    error = str(exc)

            delivery = EventDelivery(
                event_id=dead_letter.event.event_id,
                subscriber_name=dead_letter.subscriber_name,
                delivered=delivered,
                attempts=attempts,
                error=error,
            )
            results.append(delivery)
            self.history.append(delivery)

            if not delivered:
                self.dead_letters.append(
                    DeadLetter(
                        event=dead_letter.event,
                        subscriber_name=dead_letter.subscriber_name,
                        attempts=attempts,
                        error=error,
                    )
                )

        return tuple(results)