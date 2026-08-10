from __future__ import annotations

from typing import Any, Callable

from .compensation import CompensationRegistry
from .events import OrchestrationEventLedger
from .governance import RetryPolicy


Handler = Callable[[dict[str, Any]], dict[str, Any]]


class GovernedExecutionRuntime:
    """Runtime gobernado con retries, eventos y compensaciÃ³n."""

    def __init__(
        self,
        *,
        ledger: OrchestrationEventLedger,
        compensation: CompensationRegistry,
        retry_policy: RetryPolicy | None = None,
    ) -> None:
        self.ledger = ledger
        self.compensation = compensation
        self.retry_policy = retry_policy or RetryPolicy()
        self.retry_policy.validate()

    def execute(
        self,
        *,
        orchestration_id: str,
        component: str,
        expected_status: str,
        handler: Handler,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="STEP_STARTED",
            payload={"component": component},
        )

        last_error: Exception | None = None
        for attempt in range(1, self.retry_policy.max_attempts + 1):
            self.ledger.append(
                orchestration_id=orchestration_id,
                event_type="STEP_ATTEMPT",
                payload={"component": component, "attempt": attempt},
            )
            try:
                result = dict(handler(dict(payload)) or {})
                status = str(result.get("status") or "")
                if status != expected_status:
                    raise ValueError(
                        f"{component} returned {status!r}; "
                        f"expected {expected_status!r}."
                    )

                self.ledger.append(
                    orchestration_id=orchestration_id,
                    event_type="STEP_SUCCEEDED",
                    payload={
                        "component": component,
                        "attempt": attempt,
                        "status": status,
                    },
                )
                return result
            except Exception as exc:
                last_error = exc
                retryable = type(exc).__name__ in self.retry_policy.retryable_exceptions
                self.ledger.append(
                    orchestration_id=orchestration_id,
                    event_type="STEP_FAILED",
                    payload={
                        "component": component,
                        "attempt": attempt,
                        "error_type": type(exc).__name__,
                        "retryable": retryable,
                    },
                )
                if not retryable or attempt >= self.retry_policy.max_attempts:
                    break

        compensation = self.compensation.compensate(
            component,
            {
                "orchestration_id": orchestration_id,
                "component": component,
                "payload": dict(payload),
            },
        )
        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="COMPENSATION_EXECUTED",
            payload=compensation.to_dict(),
        )

        if last_error is None:
            raise RuntimeError(f"{component} failed without an exception.")
        raise last_error
