import json
from pathlib import Path

from sgoda.platform import (
    PlatformRequest,
    build_runtime,
    default_registry,
    module_health,
)


def _graph_path(tmp_path: Path) -> Path:
    path = tmp_path / "graph.json"
    path.write_text(
        json.dumps(
            {
                "nodes": [
                    {
                        "node_id": "LEX-001",
                        "node_type": "lexical_entry",
                        "label": "AMDA",
                        "language": "pu",
                        "validated": True,
                        "source_ref": "RLB:LEX-001",
                    },
                    {
                        "node_id": "CON-001",
                        "node_type": "concept",
                        "label": "Casa",
                        "validated": True,
                    },
                ],
                "edges": [
                    {
                        "source_id": "LEX-001",
                        "target_id": "CON-001",
                        "relation_type": "related_to",
                        "validated": True,
                        "weight": 1.0,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_010_registers_integrated_capabilities():
    registry = default_registry()

    assert len(registry.all()) == 8
    assert "conversation" in registry.operations()
    assert "reasoning" in registry.operations()


def test_SPT_010_rejects_duplicate_capability():
    registry = default_registry()
    capability = registry.all()[0]

    try:
        registry.register(capability)
    except ValueError:
        pass
    else:
        raise AssertionError("Se aceptó una capacidad duplicada")


def test_SPT_010_executes_knowledge_query(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="knowledge",
            context_node_id="LEX-001",
        )
    )

    assert result.status == "ok"
    assert result.data["nodes"]
    assert result.no_invention is True


def test_SPT_010_executes_reasoning_query(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="reasoning",
            context_node_id="LEX-001",
            payload={
                "question": "Explica la relación",
            },
        )
    )

    assert result.status == "ok"
    assert result.data["conclusions"]


def test_SPT_010_builds_learning_path(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="learning_path",
            context_node_id="LEX-001",
            session_id="USR-001",
        )
    )

    assert result.status == "ok"
    assert result.data["activities"]


def test_SPT_010_executes_conversation(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="conversation",
            context_node_id="LEX-001",
            session_id="SES-001",
            payload={
                "message": "Quiero aprender esta palabra",
            },
        )
    )

    assert result.status == "ok"
    assert result.data["intent"] == "tutor"


def test_SPT_010_identity_is_configurable(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="identity",
            payload={"display_name": "Nombre Comunitario"},
        )
    )

    assert result.data["display_name"] == "Nombre Comunitario"
    assert result.data["requires_community_approval"] is True


def test_SPT_010_reports_pending_adapter(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="translate",
            payload={"text": "casa"},
        )
    )

    assert result.status == "adapter_pending"
    assert result.warnings


def test_SPT_010_rejects_unknown_operation(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(operation="unknown")
    )

    assert result.status == "unsupported_operation"


def test_SPT_010_module_health_detects_components():
    health = module_health()

    assert health["knowledge_engine"] is True
    assert health["conversation"] is True
    assert all(health.values())


def test_SPT_010_is_deterministic(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    request = PlatformRequest(
        operation="knowledge",
        context_node_id="LEX-001",
    )

    assert runtime.execute(request) == runtime.execute(request)


def test_SPT_010_preserves_no_invention(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="knowledge",
            context_node_id="UNKNOWN",
        )
    )

    assert result.no_invention is True
    assert result.status == "not_found"