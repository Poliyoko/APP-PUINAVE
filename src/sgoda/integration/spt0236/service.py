from __future__ import annotations

from typing import Any, Callable

from .planner import build_orchestration_plan
from .state import OrchestrationStateStore


StepHandler = Callable[[dict[str, Any]], dict[str, Any]]


class Spt0236Layer1Service:
    """Orquestador institucional reutilizando componentes ya existentes."""

    def __init__(self, state_store: OrchestrationStateStore) -> None:
        self.state_store = state_store

    def create_run(
        self,
        *,
        lexical_id: str,
        current_status: str = "NEW",
    ) -> dict[str, Any]:
        plan = build_orchestration_plan(
            lexical_id=lexical_id,
            current_status=current_status,
        ).to_dict()

        run = {
            "orchestration_id": plan["orchestration_id"],
            "lexical_id": lexical_id,
            "status": current_status,
            "current_step": None,
            "completed_steps": [],
            "failed_steps": [],
            "plan": plan,
            "runtime": {
                "n8n_required": False,
                "fastapi_required": False,
                "paid_api_used": False,
            },
        }
        return self.state_store.save_run(run)

    def execute_with_handlers(
        self,
        *,
        orchestration_id: str,
        handlers: dict[str, StepHandler],
    ) -> dict[str, Any]:
        run = self.state_store.get(orchestration_id)
        if run is None:
            raise ValueError("Orchestration run not found.")

        plan = dict(run["plan"])
        completed = list(run.get("completed_steps") or [])
        failed = list(run.get("failed_steps") or [])
        status = str(run.get("status") or "NEW")

        for step in plan["steps"]:
            step_id = step["step_id"]
            if step_id in completed:
                status = step["success_status"]
                continue

            required = step["required_input_status"]
            if required is not None and status != required:
                raise ValueError(
                    f"Step {step_id} requires status {required}, got {status}."
                )

            handler = handlers.get(step["component"])
            if handler is None:
                if step.get("critical", True):
                    raise ValueError(
                        f"Missing handler for critical component {step['component']}."
                    )
                completed.append(step_id)
                status = step["success_status"]
                continue

            run["current_step"] = step_id
            self.state_store.save_run(run)

            try:
                result = handler(
                    {
                        "orchestration_id": orchestration_id,
                        "lexical_id": run["lexical_id"],
                        "status": status,
                        "step": step,
                    }
                )
            except Exception:
                failed.append(step_id)
                run["failed_steps"] = failed
                run["status"] = status
                self.state_store.save_run(run)
                raise

            if str(result.get("status") or "") != step["success_status"]:
                failed.append(step_id)
                run["failed_steps"] = failed
                run["status"] = status
                self.state_store.save_run(run)
                raise ValueError(
                    f"Handler for {step['component']} returned invalid status."
                )

            completed.append(step_id)
            status = step["success_status"]
            run["completed_steps"] = completed
            run["status"] = status
            run["current_step"] = None
            self.state_store.save_run(run)

        run["status"] = status
        run["current_step"] = None
        run["completed_steps"] = completed
        run["failed_steps"] = failed
        run["orchestration_complete"] = len(completed) == len(plan["steps"])
        run["next_component"] = (
            "SPT-023.6-CAPA-2"
            if run["orchestration_complete"]
            else "SPT-023.6-CAPA-1"
        )
        return self.state_store.save_run(run)
