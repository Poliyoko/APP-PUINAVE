from __future__ import annotations

from .models import OrchestrationStep


PIPELINE = (
    OrchestrationStep(
        step_id="STEP-01",
        component="SPT-023.1",
        action="DETECT_NEW_WORD",
        required_input_status=None,
        success_status="WORD_DETECTED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-02",
        component="SPT-023.2",
        action="SEMANTIC_ANALYSIS",
        required_input_status="WORD_DETECTED",
        success_status="SEMANTICALLY_VALIDATED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-03",
        component="SPT-023.3",
        action="CATEGORY_ASSIGNMENT",
        required_input_status="SEMANTICALLY_VALIDATED",
        success_status="CATEGORY_READY",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-04",
        component="SPT-023.4",
        action="MULTIMEDIA_GENERATION",
        required_input_status="CATEGORY_READY",
        success_status="READY_FOR_FLD_ODA",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-05",
        component="SPT-023.5",
        action="BUILD_AND_PUBLISH_FLD_ODA",
        required_input_status="READY_FOR_FLD_ODA",
        success_status="PUBLISHED_FLD_ODA",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-06",
        component="PMO_DIGITAL",
        action="REGISTER_PROJECT_STATE",
        required_input_status="PUBLISHED_FLD_ODA",
        success_status="PMO_REGISTERED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-07",
        component="AUDITOR_INSTITUCIONAL",
        action="RUN_INSTITUTIONAL_AUDIT",
        required_input_status="PMO_REGISTERED",
        success_status="AUDIT_APPROVED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-08",
        component="SGD-002",
        action="UPDATE_MASTER_BOOK",
        required_input_status="AUDIT_APPROVED",
        success_status="MASTER_BOOK_UPDATED",
        critical=True,
        metadata={"reuse": True},
    ),
    OrchestrationStep(
        step_id="STEP-09",
        component="N8N",
        action="COORDINATE_WORKFLOW",
        required_input_status="MASTER_BOOK_UPDATED",
        success_status="WORKFLOW_COORDINATED",
        critical=False,
        metadata={"reuse": True, "optional_runtime": True},
    ),
    OrchestrationStep(
        step_id="STEP-10",
        component="FASTAPI",
        action="EXPOSE_ORCHESTRATION_STATE",
        required_input_status="WORKFLOW_COORDINATED",
        success_status="ORCHESTRATION_EXPOSED",
        critical=False,
        metadata={"reuse": True},
    ),
)


def validate_pipeline_contract() -> None:
    if len(PIPELINE) != 10:
        raise ValueError("SPT-023.6 pipeline must define exactly ten steps.")

    ids = [step.step_id for step in PIPELINE]
    if len(set(ids)) != len(ids):
        raise ValueError("Orchestration step ids must be unique.")

    previous_status = None
    for index, step in enumerate(PIPELINE):
        if index == 0:
            if step.required_input_status is not None:
                raise ValueError("First orchestration step cannot require prior status.")
        else:
            if step.required_input_status != previous_status:
                raise ValueError(
                    f"Pipeline status chain broken at {step.step_id}: "
                    f"{step.required_input_status!r} != {previous_status!r}"
                )
        previous_status = step.success_status
