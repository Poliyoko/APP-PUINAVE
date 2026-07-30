"""Pruebas de la fachada del subsistema de gobernanza."""

from __future__ import annotations

import ast
import inspect
import json
from pathlib import Path

import pytest

from sgoda.governance.governance_service import (
    GovernanceService,
)
from sgoda.governance.models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
)
from sgoda.governance.policy_repository import (
    PolicyAlreadyExistsError,
    PolicyNotFoundError,
    PolicyRepository,
)
from sgoda.governance.results import (
    PolicyResult,
    PolicyResultStatus,
)


def make_policy(
    policy_id: str = "policy.default",
    *,
    enabled: bool = True,
    version: str = "1.0.0",
    field: str = "governance.owner",
) -> PolicyDefinition:
    return PolicyDefinition(
        policy_id=policy_id,
        name=f"Política {policy_id}",
        version=version,
        enabled=enabled,
        rules=(
            PolicyRule(
                rule_id="field-exists",
                field=field,
                operator=PolicyOperator.EXISTS,
            ),
        ),
    )


def write_policy(
    path: Path,
    *,
    policy_id: str,
    enabled: bool = True,
    version: str = "1.0.0",
) -> Path:
    data = {
        "policy_id": policy_id,
        "name": f"Política {policy_id}",
        "version": version,
        "enabled": enabled,
        "rules": [
            {
                "rule_id": "field-exists",
                "field": "governance.owner",
                "operator": "exists",
                "severity": "error",
            },
        ],
        "metadata": {},
    }

    path.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    return path


def test_constructor_creates_repository() -> None:
    service = GovernanceService()

    assert isinstance(
        service.repository,
        PolicyRepository,
    )
    assert service.policy_ids() == ()


def test_constructor_uses_supplied_repository() -> None:
    repository = PolicyRepository(
        (
            make_policy("policy.existing"),
        )
    )

    service = GovernanceService(repository)

    assert service.repository is repository
    assert service.policy_ids() == (
        "policy.existing",
    )


@pytest.mark.parametrize(
    "invalid_repository",
    [
        object(),
        {},
        [],
        "repository",
        1,
    ],
)
def test_constructor_rejects_invalid_repository(
    invalid_repository: object,
) -> None:
    with pytest.raises(
        TypeError,
        match="PolicyRepository",
    ):
        GovernanceService(
            invalid_repository  # type: ignore[arg-type]
        )


def test_register_adds_policy() -> None:
    service = GovernanceService()
    policy = make_policy()

    result = service.register(policy)

    assert result is policy
    assert service.require(
        policy.policy_id
    ) is policy


def test_register_rejects_duplicate_by_default() -> None:
    service = GovernanceService()
    policy = make_policy()

    service.register(policy)

    with pytest.raises(
        PolicyAlreadyExistsError,
    ):
        service.register(policy)


def test_register_can_replace_policy() -> None:
    service = GovernanceService()

    original = make_policy(
        "policy.same",
        version="1.0.0",
    )
    replacement = make_policy(
        "policy.same",
        version="2.0.0",
    )

    service.register(original)
    result = service.register(
        replacement,
        replace=True,
    )

    assert result is replacement
    assert service.require(
        "policy.same"
    ) is replacement


@pytest.mark.parametrize(
    "invalid_replace",
    [
        None,
        0,
        1,
        "true",
        [],
    ],
)
def test_register_rejects_invalid_replace(
    invalid_replace: object,
) -> None:
    service = GovernanceService()

    with pytest.raises(
        TypeError,
        match="replace must be a boolean",
    ):
        service.register(
            make_policy(),
            replace=invalid_replace,  # type: ignore[arg-type]
        )


def test_register_many_is_sorted() -> None:
    service = GovernanceService()

    registered = service.register_many(
        (
            make_policy("policy.z"),
            make_policy("policy.a"),
            make_policy("policy.m"),
        )
    )

    assert tuple(
        policy.policy_id
        for policy in registered
    ) == (
        "policy.a",
        "policy.m",
        "policy.z",
    )

    assert service.policy_ids() == (
        "policy.a",
        "policy.m",
        "policy.z",
    )


def test_register_many_accepts_generator() -> None:
    service = GovernanceService()

    registered = service.register_many(
        make_policy(f"policy.{index}")
        for index in range(3)
    )

    assert tuple(
        policy.policy_id
        for policy in registered
    ) == (
        "policy.0",
        "policy.1",
        "policy.2",
    )


def test_register_many_rejects_internal_duplicates() -> None:
    service = GovernanceService()

    with pytest.raises(Exception):
        service.register_many(
            (
                make_policy("policy.same"),
                make_policy("policy.same"),
            )
        )

    assert service.policy_ids() == ()


def test_register_many_is_atomic_on_existing_id() -> None:
    existing = make_policy("policy.existing")
    service = GovernanceService(
        PolicyRepository((existing,))
    )

    new_policy = make_policy("policy.new")
    duplicate = make_policy(
        "policy.existing",
        version="2.0.0",
    )

    with pytest.raises(
        PolicyAlreadyExistsError,
    ):
        service.register_many(
            (
                new_policy,
                duplicate,
            )
        )

    assert service.policy_ids() == (
        "policy.existing",
    )
    assert service.require(
        "policy.existing"
    ) is existing


def test_register_many_can_replace() -> None:
    original = make_policy(
        "policy.same",
        version="1.0.0",
    )

    service = GovernanceService(
        PolicyRepository((original,))
    )

    replacement = make_policy(
        "policy.same",
        version="2.0.0",
    )
    additional = make_policy("policy.additional")

    registered = service.register_many(
        (
            replacement,
            additional,
        ),
        replace=True,
    )

    assert tuple(
        policy.policy_id
        for policy in registered
    ) == (
        "policy.additional",
        "policy.same",
    )
    assert service.require(
        "policy.same"
    ) is replacement


def test_load_registers_policy(
    tmp_path: Path,
) -> None:
    path = write_policy(
        tmp_path / "policy.json",
        policy_id="policy.loaded",
    )

    service = GovernanceService()

    loaded = service.load(path)

    assert loaded.policy_id == "policy.loaded"
    assert service.require(
        "policy.loaded"
    ) is loaded


def test_load_rejects_duplicate_by_default(
    tmp_path: Path,
) -> None:
    path = write_policy(
        tmp_path / "policy.json",
        policy_id="policy.loaded",
    )

    service = GovernanceService()
    first = service.load(path)

    with pytest.raises(
        PolicyAlreadyExistsError,
    ):
        service.load(path)

    assert service.require(
        "policy.loaded"
    ) is first


def test_load_can_replace(
    tmp_path: Path,
) -> None:
    first_path = write_policy(
        tmp_path / "first.json",
        policy_id="policy.loaded",
        version="1.0.0",
    )
    second_path = write_policy(
        tmp_path / "second.json",
        policy_id="policy.loaded",
        version="2.0.0",
    )

    service = GovernanceService()

    service.load(first_path)
    replacement = service.load(
        second_path,
        replace=True,
    )

    assert replacement.version == "2.0.0"
    assert service.require(
        "policy.loaded"
    ) is replacement


def test_load_many_registers_policies(
    tmp_path: Path,
) -> None:
    first = write_policy(
        tmp_path / "first.json",
        policy_id="policy.first",
    )
    second = write_policy(
        tmp_path / "second.json",
        policy_id="policy.second",
        enabled=False,
    )

    service = GovernanceService()

    loaded = service.load_many(
        (
            second,
            first,
        )
    )

    assert tuple(
        policy.policy_id
        for policy in loaded
    ) == (
        "policy.first",
        "policy.second",
    )

    assert service.policy_ids() == (
        "policy.first",
        "policy.second",
    )


def test_load_many_does_not_modify_repository_on_load_error(
    tmp_path: Path,
) -> None:
    existing = make_policy("policy.existing")

    service = GovernanceService(
        PolicyRepository((existing,))
    )

    valid = write_policy(
        tmp_path / "valid.json",
        policy_id="policy.valid",
    )
    missing = tmp_path / "missing.json"

    with pytest.raises(Exception):
        service.load_many(
            (
                valid,
                missing,
            )
        )

    assert service.policy_ids() == (
        "policy.existing",
    )


def test_get_and_require() -> None:
    policy = make_policy()
    service = GovernanceService(
        PolicyRepository((policy,))
    )

    assert service.get(
        policy.policy_id
    ) is policy
    assert service.get(
        "policy.missing"
    ) is None
    assert service.require(
        policy.policy_id
    ) is policy


def test_require_missing_raises() -> None:
    service = GovernanceService()

    with pytest.raises(
        PolicyNotFoundError,
    ):
        service.require(
            "policy.missing"
        )


def test_remove() -> None:
    policy = make_policy()
    service = GovernanceService(
        PolicyRepository((policy,))
    )

    removed = service.remove(
        policy.policy_id
    )

    assert removed is policy
    assert service.policy_ids() == ()


def test_policies_and_policy_ids_filter_enabled() -> None:
    service = GovernanceService(
        PolicyRepository(
            (
                make_policy(
                    "policy.enabled",
                    enabled=True,
                ),
                make_policy(
                    "policy.disabled",
                    enabled=False,
                ),
            )
        )
    )

    assert service.policy_ids(
        enabled=True
    ) == (
        "policy.enabled",
    )
    assert service.policy_ids(
        enabled=False
    ) == (
        "policy.disabled",
    )

    assert tuple(
        policy.policy_id
        for policy in service.policies(
            enabled=True
        )
    ) == (
        "policy.enabled",
    )


def test_evaluate_registered_policy() -> None:
    service = GovernanceService(
        PolicyRepository(
            (
                make_policy("policy.owner"),
            )
        )
    )

    result = service.evaluate(
        "policy.owner",
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
    )

    assert isinstance(result, PolicyResult)
    assert result.policy_id == "policy.owner"
    assert result.status is PolicyResultStatus.PASSED


def test_evaluate_missing_policy_raises() -> None:
    service = GovernanceService()

    with pytest.raises(
        PolicyNotFoundError,
    ):
        service.evaluate(
            "policy.missing",
            {},
        )


def test_evaluate_all_is_deterministic() -> None:
    service = GovernanceService(
        PolicyRepository(
            (
                make_policy("policy.z"),
                make_policy("policy.a"),
            )
        )
    )

    results = service.evaluate_all(
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        }
    )

    assert tuple(
        result.policy_id
        for result in results
    ) == (
        "policy.a",
        "policy.z",
    )
    assert all(
        result.status
        is PolicyResultStatus.PASSED
        for result in results
    )


def test_evaluate_all_includes_disabled_as_skipped() -> None:
    service = GovernanceService(
        PolicyRepository(
            (
                make_policy(
                    "policy.enabled",
                    enabled=True,
                ),
                make_policy(
                    "policy.disabled",
                    enabled=False,
                ),
            )
        )
    )

    results = service.evaluate_all(
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        }
    )

    statuses = {
        result.policy_id: result.status
        for result in results
    }

    assert (
        statuses["policy.enabled"]
        is PolicyResultStatus.PASSED
    )
    assert (
        statuses["policy.disabled"]
        is PolicyResultStatus.SKIPPED
    )


def test_evaluate_all_can_select_enabled_only() -> None:
    service = GovernanceService(
        PolicyRepository(
            (
                make_policy(
                    "policy.enabled",
                    enabled=True,
                ),
                make_policy(
                    "policy.disabled",
                    enabled=False,
                ),
            )
        )
    )

    results = service.evaluate_all(
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
        enabled=True,
    )

    assert tuple(
        result.policy_id
        for result in results
    ) == (
        "policy.enabled",
    )


def test_evaluate_all_empty_repository() -> None:
    service = GovernanceService()

    assert service.evaluate_all(
        {},
    ) == ()


def test_clear() -> None:
    first = make_policy("policy.first")
    second = make_policy("policy.second")

    service = GovernanceService(
        PolicyRepository(
            (
                second,
                first,
            )
        )
    )

    removed = service.clear()

    assert removed == (
        first,
        second,
    )
    assert service.policy_ids() == ()


def test_module_has_no_forbidden_dependencies() -> None:
    path = Path(
        "src/sgoda/governance/governance_service.py"
    )

    tree = ast.parse(
        path.read_text(
            encoding="utf-8-sig"
        ),
        filename=str(path),
    )

    prohibited = (
        "sgoda.audit",
        "sgoda.cli",
        "sgoda.services",
        "sgoda.operations",
        "sgoda.repositories",
    )

    violations: list[str] = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules = [
                alias.name
                for alias in node.names
            ]
        elif isinstance(node, ast.ImportFrom):
            modules = (
                [node.module]
                if node.module
                else []
            )
        else:
            continue

        for module in modules:
            if any(
                module == prefix
                or module.startswith(
                    f"{prefix}."
                )
                for prefix in prohibited
            ):
                violations.append(module)

    assert not violations


def test_public_api() -> None:
    import sgoda.governance.governance_service as module

    assert module.__all__ == [
        "GovernanceService",
    ]

    assert tuple(
        inspect.signature(
            GovernanceService
        ).parameters
    ) == (
        "repository",
    )

    expected = {
        "register": (
            "self",
            "policy",
            "replace",
        ),
        "register_many": (
            "self",
            "policies",
            "replace",
        ),
        "load": (
            "self",
            "path",
            "replace",
        ),
        "load_many": (
            "self",
            "paths",
            "replace",
        ),
        "get": (
            "self",
            "policy_id",
            "default",
        ),
        "require": (
            "self",
            "policy_id",
        ),
        "remove": (
            "self",
            "policy_id",
        ),
        "policies": (
            "self",
            "enabled",
        ),
        "policy_ids": (
            "self",
            "enabled",
        ),
        "evaluate": (
            "self",
            "policy_id",
            "values",
        ),
        "evaluate_all": (
            "self",
            "values",
            "enabled",
        ),
        "clear": (
            "self",
        ),
    }

    for method_name, parameters in expected.items():
        signature = inspect.signature(
            getattr(
                GovernanceService,
                method_name,
            )
        )

        assert tuple(
            signature.parameters
        ) == parameters

    for method_name in (
        "register",
        "register_many",
        "load",
        "load_many",
    ):
        signature = inspect.signature(
            getattr(
                GovernanceService,
                method_name,
            )
        )

        assert (
            signature.parameters[
                "replace"
            ].kind
            is inspect.Parameter.KEYWORD_ONLY
        )

    for method_name in (
        "policies",
        "policy_ids",
        "evaluate_all",
    ):
        signature = inspect.signature(
            getattr(
                GovernanceService,
                method_name,
            )
        )

        assert (
            signature.parameters[
                "enabled"
            ].kind
            is inspect.Parameter.KEYWORD_ONLY
        )
