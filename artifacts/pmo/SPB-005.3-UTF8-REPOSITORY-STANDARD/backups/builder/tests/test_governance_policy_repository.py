"""Pruebas del repositorio de políticas de gobernanza."""

from __future__ import annotations

import ast
import inspect
from pathlib import Path

import pytest

from sgoda.governance.exceptions import PolicyValidationError
from sgoda.governance.models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
)
from sgoda.governance.policy_repository import (
    PolicyAlreadyExistsError,
    PolicyNotFoundError,
    PolicyRepository,
    PolicyRepositoryError,
)


def make_policy(
    policy_id: str = "policy.default",
    *,
    enabled: bool = True,
    name: str | None = None,
    version: str = "1.0.0",
) -> PolicyDefinition:
    return PolicyDefinition(
        policy_id=policy_id,
        name=name or f"Política {policy_id}",
        version=version,
        enabled=enabled,
        rules=(
            PolicyRule(
                rule_id="owner-exists",
                field="governance.owner",
                operator=PolicyOperator.EXISTS,
            ),
        ),
    )


def test_empty_repository() -> None:
    repository = PolicyRepository()

    assert len(repository) == 0
    assert not repository
    assert repository.list() == ()
    assert repository.ids() == ()
    assert tuple(repository) == ()


def test_constructor_accepts_policies() -> None:
    first = make_policy("policy.first")
    second = make_policy("policy.second")

    repository = PolicyRepository(
        (
            first,
            second,
        )
    )

    assert len(repository) == 2
    assert repository.require(
        "policy.first"
    ) is first
    assert repository.require(
        "policy.second"
    ) is second


def test_constructor_accepts_generator() -> None:
    repository = PolicyRepository(
        make_policy(f"policy.{index}")
        for index in range(3)
    )

    assert repository.ids() == (
        "policy.0",
        "policy.1",
        "policy.2",
    )


def test_constructor_rejects_duplicate_ids() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="identifiers must be unique",
    ):
        PolicyRepository(
            (
                make_policy("policy.same"),
                make_policy("policy.same"),
            )
        )


@pytest.mark.parametrize(
    "invalid_policies",
    [
        None,
        1,
        "policies",
        b"policies",
        {},
    ],
)
def test_constructor_rejects_invalid_collections(
    invalid_policies: object,
) -> None:
    with pytest.raises(PolicyValidationError):
        PolicyRepository(
            invalid_policies  # type: ignore[arg-type]
        )


def test_add_returns_same_instance() -> None:
    repository = PolicyRepository()
    policy = make_policy()

    stored = repository.add(policy)

    assert stored is policy
    assert repository.require(
        policy.policy_id
    ) is policy


def test_add_rejects_duplicate() -> None:
    repository = PolicyRepository()
    policy = make_policy()

    repository.add(policy)

    with pytest.raises(
        PolicyAlreadyExistsError,
        match="policy already exists",
    ) as exc_info:
        repository.add(policy)

    assert exc_info.value.policy_id == (
        policy.policy_id
    )


def test_repository_errors_share_base_class() -> None:
    assert issubclass(
        PolicyAlreadyExistsError,
        PolicyRepositoryError,
    )
    assert issubclass(
        PolicyNotFoundError,
        PolicyRepositoryError,
    )


def test_upsert_adds_new_policy() -> None:
    repository = PolicyRepository()
    policy = make_policy()

    assert repository.upsert(policy) is policy
    assert repository.require(
        policy.policy_id
    ) is policy


def test_upsert_replaces_existing_policy() -> None:
    repository = PolicyRepository()

    original = make_policy(
        "policy.same",
        version="1.0.0",
    )
    replacement = make_policy(
        "policy.same",
        version="2.0.0",
    )

    repository.add(original)
    result = repository.upsert(replacement)

    assert result is replacement
    assert repository.require(
        "policy.same"
    ) is replacement
    assert len(repository) == 1


def test_get_existing_policy() -> None:
    policy = make_policy()
    repository = PolicyRepository((policy,))

    assert repository.get(
        policy.policy_id
    ) is policy


def test_get_missing_returns_none() -> None:
    repository = PolicyRepository()

    assert repository.get(
        "policy.missing"
    ) is None


def test_get_missing_returns_custom_default() -> None:
    repository = PolicyRepository()
    default = object()

    assert repository.get(
        "policy.missing",
        default,
    ) is default


def test_require_missing_raises() -> None:
    repository = PolicyRepository()

    with pytest.raises(
        PolicyNotFoundError,
        match="policy not found",
    ) as exc_info:
        repository.require(
            "policy.missing"
        )

    assert (
        exc_info.value.policy_id
        == "policy.missing"
    )


def test_remove_returns_policy() -> None:
    policy = make_policy()
    repository = PolicyRepository((policy,))

    removed = repository.remove(
        policy.policy_id
    )

    assert removed is policy
    assert len(repository) == 0


def test_remove_missing_raises() -> None:
    repository = PolicyRepository()

    with pytest.raises(
        PolicyNotFoundError,
        match="policy not found",
    ):
        repository.remove(
            "policy.missing"
        )


def test_contains_method() -> None:
    policy = make_policy()
    repository = PolicyRepository((policy,))

    assert repository.contains(
        policy.policy_id
    )
    assert not repository.contains(
        "policy.missing"
    )


def test_contains_operator() -> None:
    policy = make_policy()
    repository = PolicyRepository((policy,))

    assert policy.policy_id in repository
    assert "policy.missing" not in repository
    assert object() not in repository


@pytest.mark.parametrize(
    "invalid_policy_id",
    [
        None,
        1,
        "",
        "   ",
        " policy.id",
        "policy.id ",
    ],
)
@pytest.mark.parametrize(
    "method_name",
    [
        "get",
        "require",
        "remove",
        "contains",
    ],
)
def test_methods_validate_policy_id(
    method_name: str,
    invalid_policy_id: object,
) -> None:
    repository = PolicyRepository()

    method = getattr(
        repository,
        method_name,
    )

    with pytest.raises(PolicyValidationError):
        method(
            invalid_policy_id
        )


def test_list_is_sorted_by_policy_id() -> None:
    repository = PolicyRepository(
        (
            make_policy("policy.z"),
            make_policy("policy.a"),
            make_policy("policy.m"),
        )
    )

    assert tuple(
        policy.policy_id
        for policy in repository.list()
    ) == (
        "policy.a",
        "policy.m",
        "policy.z",
    )


def test_iteration_is_sorted() -> None:
    repository = PolicyRepository(
        (
            make_policy("policy.z"),
            make_policy("policy.a"),
        )
    )

    assert tuple(
        policy.policy_id
        for policy in repository
    ) == (
        "policy.a",
        "policy.z",
    )


def test_ids_follow_list_order() -> None:
    repository = PolicyRepository(
        (
            make_policy("policy.z"),
            make_policy("policy.a"),
        )
    )

    assert repository.ids() == (
        "policy.a",
        "policy.z",
    )


def test_list_filters_enabled_policies() -> None:
    repository = PolicyRepository(
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

    assert repository.ids(
        enabled=True
    ) == (
        "policy.enabled",
    )

    assert repository.ids(
        enabled=False
    ) == (
        "policy.disabled",
    )


@pytest.mark.parametrize(
    "invalid_enabled",
    [
        0,
        1,
        "true",
        [],
    ],
)
def test_list_rejects_invalid_enabled_filter(
    invalid_enabled: object,
) -> None:
    repository = PolicyRepository()

    with pytest.raises(
        PolicyValidationError,
        match="boolean or None",
    ):
        repository.list(
            enabled=invalid_enabled,  # type: ignore[arg-type]
        )


def test_clear_returns_previous_contents() -> None:
    first = make_policy("policy.first")
    second = make_policy("policy.second")

    repository = PolicyRepository(
        (
            second,
            first,
        )
    )

    removed = repository.clear()

    assert removed == (
        first,
        second,
    )
    assert len(repository) == 0
    assert repository.list() == ()


def test_disabled_policies_are_supported() -> None:
    policy = make_policy(
        enabled=False,
    )

    repository = PolicyRepository((policy,))

    assert repository.require(
        policy.policy_id
    ) is policy
    assert repository.ids(
        enabled=False
    ) == (
        policy.policy_id,
    )


def test_invalid_policy_is_rejected_by_add() -> None:
    repository = PolicyRepository()

    invalid = make_policy(
        "invalid policy id",
    )

    with pytest.raises(
        PolicyValidationError,
        match="unsupported characters",
    ):
        repository.add(invalid)


def test_invalid_policy_is_rejected_by_upsert() -> None:
    repository = PolicyRepository()

    invalid = make_policy(
        "invalid policy id",
    )

    with pytest.raises(
        PolicyValidationError,
        match="unsupported characters",
    ):
        repository.upsert(invalid)


def test_module_has_no_forbidden_dependencies() -> None:
    path = Path(
        "src/sgoda/governance/policy_repository.py"
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
        "sgoda.governance.policy_engine",
        "sgoda.governance.rule_evaluator",
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
    import sgoda.governance.policy_repository as module

    assert module.__all__ == [
        "PolicyAlreadyExistsError",
        "PolicyNotFoundError",
        "PolicyRepository",
        "PolicyRepositoryError",
    ]

    constructor = inspect.signature(
        PolicyRepository
    )
    add_signature = inspect.signature(
        PolicyRepository.add
    )
    upsert_signature = inspect.signature(
        PolicyRepository.upsert
    )
    get_signature = inspect.signature(
        PolicyRepository.get
    )
    require_signature = inspect.signature(
        PolicyRepository.require
    )
    remove_signature = inspect.signature(
        PolicyRepository.remove
    )
    contains_signature = inspect.signature(
        PolicyRepository.contains
    )
    list_signature = inspect.signature(
        PolicyRepository.list
    )
    ids_signature = inspect.signature(
        PolicyRepository.ids
    )
    clear_signature = inspect.signature(
        PolicyRepository.clear
    )

    assert tuple(
        constructor.parameters
    ) == (
        "policies",
    )

    assert tuple(
        add_signature.parameters
    ) == (
        "self",
        "policy",
    )

    assert tuple(
        upsert_signature.parameters
    ) == (
        "self",
        "policy",
    )

    assert tuple(
        get_signature.parameters
    ) == (
        "self",
        "policy_id",
        "default",
    )

    assert tuple(
        require_signature.parameters
    ) == (
        "self",
        "policy_id",
    )

    assert tuple(
        remove_signature.parameters
    ) == (
        "self",
        "policy_id",
    )

    assert tuple(
        contains_signature.parameters
    ) == (
        "self",
        "policy_id",
    )

    assert tuple(
        list_signature.parameters
    ) == (
        "self",
        "enabled",
    )

    assert (
        list_signature.parameters[
            "enabled"
        ].kind
        is inspect.Parameter.KEYWORD_ONLY
    )

    assert tuple(
        ids_signature.parameters
    ) == (
        "self",
        "enabled",
    )

    assert (
        ids_signature.parameters[
            "enabled"
        ].kind
        is inspect.Parameter.KEYWORD_ONLY
    )

    assert tuple(
        clear_signature.parameters
    ) == (
        "self",
    )
