from __future__ import annotations

from dataclasses import dataclass

from .policy import SecretManagementPolicy


@dataclass(frozen=True)
class SecureStoragePlan:
    backend: str
    repository_storage_allowed: bool
    plaintext_allowed: bool
    instructions: tuple[str, ...]

    def to_dict(self) -> dict:
        return {
            "backend": self.backend,
            "repository_storage_allowed": self.repository_storage_allowed,
            "plaintext_allowed": self.plaintext_allowed,
            "instructions": list(self.instructions),
        }


class SecureStoragePlanner:
    def __init__(
        self,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.policy = policy or SecretManagementPolicy.default()

    def plan(self, *, preferred_backend: str = "ENVIRONMENT_VARIABLES") -> SecureStoragePlan:
        if preferred_backend not in self.policy.approved_storage_backends:
            raise ValueError("Storage backend is not institutionally approved.")

        if preferred_backend == "ENVIRONMENT_VARIABLES":
            instructions = (
                "Store runtime secrets outside Git.",
                "Inject values through environment variables.",
                "Keep only variable names and examples in repository.",
            )
        elif preferred_backend == "WINDOWS_CREDENTIAL_MANAGER":
            instructions = (
                "Store credentials in Windows Credential Manager.",
                "Reference credentials by logical target name.",
                "Never serialize secret values into project artifacts.",
            )
        else:
            instructions = (
                "Store encrypted secret material outside repository root.",
                "Restrict filesystem permissions to the runtime identity.",
                "Keep only non-sensitive metadata in SGODA evidence.",
            )

        return SecureStoragePlan(
            backend=preferred_backend,
            repository_storage_allowed=False,
            plaintext_allowed=False,
            instructions=instructions,
        )
