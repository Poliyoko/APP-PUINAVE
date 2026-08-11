"""SPT-024.9 Capa 3 â€” final IAM/PAM governance, access recertification and institutional closure."""
from .service import IdentityPrivilegeClosureService
from .gate import IdentityPrivilegeClosureGate

__all__ = ["IdentityPrivilegeClosureService", "IdentityPrivilegeClosureGate"]
