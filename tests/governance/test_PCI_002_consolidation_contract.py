
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Gate:
    name: str
    approved: bool


def final_order() -> tuple[str, ...]:
    return (
        "SGD-115",
        "SGD-116",
        "PCI-001.2",
        "SGD-117",
        "PCI-001.1",
        "FULL-SUITE",
        "SGD-114F",
        "SGD-114G",
    )


def approve(gates: tuple[Gate, ...]) -> bool:
    return bool(gates) and all(item.approved for item in gates)


def test_index_sync_runs_after_document_generation() -> None:
    order = final_order()
    assert order.index("PCI-001.2") > order.index("SGD-115")
    assert order.index("PCI-001.2") > order.index("SGD-116")


def test_audit_runs_after_index_sync() -> None:
    order = final_order()
    assert order.index("PCI-001.1") > order.index("PCI-001.2")


def test_repository_validation_runs_after_sync() -> None:
    order = final_order()
    assert order.index("SGD-117") > order.index("PCI-001.2")


def test_release_gate_is_last() -> None:
    assert final_order()[-1] == "SGD-114G"


def test_all_gates_required() -> None:
    gates = (
        Gate("index", True),
        Gate("registry", True),
        Gate("audit", True),
    )
    assert approve(gates) is True
    assert approve(gates[:-1] + (Gate("audit", False),)) is False


def test_empty_gate_set_is_not_approved() -> None:
    assert approve(()) is False
