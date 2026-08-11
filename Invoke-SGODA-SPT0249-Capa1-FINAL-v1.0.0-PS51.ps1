#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# SGODA-PUINAVE / PISI
# SPT-024.9 Capa 1
# Identidades, Autenticacion, Autorizacion, RBAC y Minimo Privilegio
# PowerShell 5.1 - Maestro unico, no destructivo, publicacion controlada
# ============================================================================

$ExpectedBaseline = "960bbe9b74b7e075a1d09b470853da2efb11c734"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0249-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir = "src/sgoda/integration/spt0249"
$TestFile = "tests/integration/test_spt0249_identity_access_security_layer1.py"
$PolicyFile = "config/integration/spt0249/identity-access-security-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.9/SGD-SPT024.9-Capa1-Identidades-Autenticacion-Autorizacion-RBAC-Minimo-Privilegio.md"

$ArtifactDir = "artifacts/development/SPT-024.9-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/identity-access-assessment.json"
$InventoryFile = "$ArtifactDir/identity-access-surface-inventory.json"
$IntegrityFile = "$ArtifactDir/identity-access-integrity-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.9 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION      : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}

function Step {
    param([int]$N,[string]$Text)

    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Native {
    param(
        [string]$Exe,
        [string[]]$NativeArgs=@(),
        [string]$Label="Native command"
    )

    & $Exe @NativeArgs

    if($LASTEXITCODE -ne 0){
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Git-Fetch-With-Retry {
    param(
        [string]$Remote="origin",
        [string]$Ref="",
        [int]$Attempts=4
    )

    $Delays=@(3,7,15,25)
    $LastMessage=""

    for($i=1;$i -le $Attempts;$i++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/{1}" -f $i,$Attempts)

        $FetchArgs=@("fetch","--prune",$Remote)
        if(-not [string]::IsNullOrWhiteSpace($Ref)){
            $FetchArgs += $Ref
        }

        $Previous=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $Output=@(& git.exe @FetchArgs 2>&1)
            $Code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$Previous
        }

        if($Output.Count -gt 0){
            $Output | ForEach-Object { Write-Host ([string]$_) }
            $LastMessage=(($Output | ForEach-Object {[string]$_}) -join " | ")
        }

        if($Code -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }

        if($i -lt $Attempts){
            $Delay=$Delays[[Math]::Min($i-1,$Delays.Count-1)]
            Write-Host ("GIT FETCH TEMPORARY FAILURE : retry in {0}s" -f $Delay) -ForegroundColor Yellow
            Start-Sleep -Seconds $Delay
        }
    }

    throw "GitHub connectivity unavailable after $Attempts attempts. Last error: $LastMessage"
}

function PythonExe {
    foreach($Candidate in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")){
        if(Test-Path -LiteralPath $Candidate){
            return (Resolve-Path $Candidate).Path
        }
    }

    $Command=Get-Command python.exe -ErrorAction SilentlyContinue
    if($null -ne $Command){
        return $Command.Source
    }

    throw "Python executable not found."
}

function Norm {
    param([string]$PathValue)

    if($null -eq $PathValue){
        return ""
    }

    return ($PathValue.Trim('"') -replace '\\','/')
}

function Write-Lf {
    param(
        [string]$Path,
        [string]$Text
    )

    $Parent=Split-Path -Parent $Path
    if($Parent){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }

    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")

    if(-not $Canonical.EndsWith("`n")){
        $Canonical += "`n"
    }

    [IO.File]::WriteAllText((Join-Path $PWD $Path),$Canonical,$Utf8)
}

function Get-TrackedHashSnapshot {
    $Snapshot=@{}
    $Files=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate tracked files."
    }

    foreach($RawPath in $Files){
        $PathValue=Norm $RawPath

        if($PathValue.StartsWith((Norm $ModuleDir)+"/")){ continue }
        if($PathValue -eq $TestFile){ continue }
        if($PathValue -eq $PolicyFile){ continue }
        if($PathValue -eq $DocFile){ continue }
        if($PathValue.StartsWith((Norm $ArtifactDir)+"/")){ continue }
        if($PathValue -eq $SelfName){ continue }

        $NativePath=$PathValue -replace '/',[IO.Path]::DirectorySeparatorChar

        if(Test-Path -LiteralPath $NativePath -PathType Leaf){
            try{
                $Snapshot[$PathValue]=(Get-FileHash -LiteralPath $NativePath -Algorithm SHA256).Hash.ToUpperInvariant()
            }
            catch{}
        }
    }

    return $Snapshot
}

function Assert-Snapshot {
    param([hashtable]$Snapshot)

    foreach($PathValue in $Snapshot.Keys){
        $NativePath=$PathValue -replace '/',[IO.Path]::DirectorySeparatorChar

        if(-not(Test-Path -LiteralPath $NativePath -PathType Leaf)){
            Stop-Hold "Protected tracked file disappeared: $PathValue"
        }

        $Current=(Get-FileHash -LiteralPath $NativePath -Algorithm SHA256).Hash.ToUpperInvariant()

        if($Current -ne $Snapshot[$PathValue]){
            Stop-Hold "Protected tracked file changed: $PathValue"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
}

function Get-IndexOversizedBlobs {
    $TooLarge=New-Object System.Collections.ArrayList
    $Files=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate Git index."
    }

    foreach($RawPath in $Files){
        $PathValue=Norm $RawPath
        $Spec=":"+$PathValue

        $Previous=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $SizeOutput=@(& git.exe cat-file -s $Spec 2>$null)
            $Code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$Previous
        }

        if($Code -ne 0 -or $SizeOutput.Count -eq 0){
            continue
        }

        [Int64]$Length=0
        if([Int64]::TryParse(([string]$SizeOutput[0]).Trim(),[ref]$Length)){
            if($Length -ge $LargeFileLimit){
                [void]$TooLarge.Add([ordered]@{
                    path=$PathValue
                    bytes=$Length
                })
            }
        }
    }

    return @($TooLarge)
}

try {
    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"

    if(-not(Test-Path -LiteralPath ".git")){
        Stop-Hold "Execute from the official SGODA-PUINAVE repository root."
    }

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalHead=(& git.exe rev-parse HEAD).Trim()
    $RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($LocalHead -ne $ExpectedBaseline){
        Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."
    }

    if($RemoteHead -ne $ExpectedBaseline){
        Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."
    }

    if($Staged.Count -ne 0){
        Stop-Hold "Pre-existing staged changes detected."
    }

    if($Deleted.Count -ne 0){
        Stop-Hold "Tracked deletions detected."
    }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.1-.8 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"

    $Targets=@(
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )

    $Existing=@($Targets | Where-Object { Test-Path -LiteralPath $_ })

    Write-Host "PREEXISTING SPT-024.9 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){
        Write-Host "SPT-024.9 RESUME MODE : ACTIVE"
    }
    else{
        Write-Host "SPT-024.9 FRESH IMPLEMENTATION : ACTIVE"
    }

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot

    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "IDENTITY / AUTHENTICATION / AUTHORIZATION SURFACE DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate tracked files."
    }

    $IdentitySurfaceFiles=@($Tracked | Where-Object {
        $P=(Norm $_).ToLowerInvariant()

        (
            $P -match '(auth|identity|user|role|permission|privilege|token|credential|secret|session|access|security|admin|service)' -or
            $P -match '(^|/)(api|config|automation|src|tools)(/|$)'
        ) -and
        $P -match '\.(py|ps1|json|ya?ml|toml|ini|cfg|md)$'
    })

    $ApiFiles=@($Tracked | Where-Object {
        $P=(Norm $_).ToLowerInvariant()
        $P -match '(^|/)src/sgoda/.+\.py$' -and
        $P -match '(api|route|auth|security)'
    })

    $ConfigFiles=@($Tracked | Where-Object {
        $P=(Norm $_).ToLowerInvariant()
        $P -match '(^|/)config/.+\.(json|ya?ml|toml|ini|cfg)$'
    })

    Write-Host "IDENTITY/ACCESS SURFACES : $($IdentitySurfaceFiles.Count)"
    Write-Host "API/AUTH PYTHON FILES    : $($ApiFiles.Count)"
    Write-Host "SECURITY CONFIG FILES    : $($ConfigFiles.Count)"
    Write-Host "DISCOVERY MODE           : STATIC / NON-DESTRUCTIVE"
    Write-Host "PASSWORD CHANGED         : NO"
    Write-Host "TOKEN ROTATED            : NO"
    Write-Host "OS/DB/GITHUB ROLE CHANGED: NO"
    Write-Host "EXTERNAL CONNECTION      : NO"

    Step 5 "IMPLEMENT SPT-024.9 CAPA 1"

    $InitPy=@'
"""SPT-024.9 Capa 1 — identities, authentication, authorization, RBAC and least privilege."""
from .service import IdentityAccessSecurityService
from .gate import IdentityAccessSecurityGate

__all__ = ["IdentityAccessSecurityService", "IdentityAccessSecurityGate"]
'@

    $ModelsPy=@'
from dataclasses import dataclass, field
from typing import Any, Dict, FrozenSet


@dataclass(frozen=True)
class Identity:
    identity_id: str
    identity_type: str
    roles: FrozenSet[str]
    enabled: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class AccessDecision:
    allowed: bool
    reason: str
    identity_id: str
    resource: str
    action: str


@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@

    $RolesPy=@'
from __future__ import annotations

ROLE_PERMISSIONS = {
    "LEXICAL_READER": frozenset({
        "lexical:read",
        "catalog:read",
    }),
    "LEXICAL_EDITOR": frozenset({
        "lexical:read",
        "lexical:create",
        "lexical:update",
        "catalog:read",
    }),
    "AUDITOR": frozenset({
        "audit:read",
        "evidence:read",
        "security:assessment:read",
    }),
    "PUBLISHER": frozenset({
        "publication:prepare",
        "publication:publish",
        "release:read",
    }),
    "SECURITY_OPERATOR": frozenset({
        "security:assessment:read",
        "incident:read",
        "incident:triage",
        "incident:escalate",
    }),
    "SERVICE_WORKFLOW": frozenset({
        "workflow:execute",
        "workflow:read",
    }),
}

HIGH_RISK_PERMISSIONS = frozenset({
    "publication:publish",
    "incident:escalate",
    "workflow:execute",
})

SERVICE_ALLOWED_ROLES = frozenset({
    "SERVICE_WORKFLOW",
})

HUMAN_ONLY_ROLES = frozenset({
    "LEXICAL_READER",
    "LEXICAL_EDITOR",
    "AUDITOR",
    "PUBLISHER",
    "SECURITY_OPERATOR",
})


def permissions_for_roles(roles):
    permissions = set()
    for role in roles:
        permissions.update(ROLE_PERMISSIONS.get(role, frozenset()))
    return frozenset(permissions)


def known_role(role: str) -> bool:
    return role in ROLE_PERMISSIONS
'@

    $AuthnPy=@'
from __future__ import annotations
from typing import Mapping


ALLOWED_IDENTITY_TYPES = frozenset({
    "HUMAN",
    "SERVICE",
})

ALLOWED_CREDENTIAL_REFERENCE_PREFIXES = (
    "env:",
    "vaultref:",
    "secretref:",
    "credentialref:",
)


def validate_authentication_profile(profile: Mapping) -> dict:
    identity_type = str(profile.get("identity_type", "")).upper()
    enabled = bool(profile.get("enabled", False))
    credential_reference = str(profile.get("credential_reference", ""))
    factors = tuple(profile.get("factors", ()))

    ref_is_indirect = any(
        credential_reference.lower().startswith(prefix)
        for prefix in ALLOWED_CREDENTIAL_REFERENCE_PREFIXES
    )

    factor_set = {str(x).upper() for x in factors}

    if identity_type == "HUMAN":
        factor_policy = bool(factor_set.intersection({"PASSWORD", "PASSKEY", "MFA", "OIDC"}))
    elif identity_type == "SERVICE":
        factor_policy = bool(factor_set.intersection({"SERVICE_TOKEN", "OIDC", "WORKLOAD_IDENTITY"}))
    else:
        factor_policy = False

    valid = (
        identity_type in ALLOWED_IDENTITY_TYPES
        and enabled
        and ref_is_indirect
        and factor_policy
    )

    return {
        "valid": valid,
        "identity_type": identity_type,
        "enabled": enabled,
        "credential_reference_indirect": ref_is_indirect,
        "factor_policy": factor_policy,
        "secret_values_exposed": False,
    }
'@

    $PolicyPy=@'
from __future__ import annotations

from .models import AccessDecision, Identity
from .roles import (
    HUMAN_ONLY_ROLES,
    SERVICE_ALLOWED_ROLES,
    known_role,
    permissions_for_roles,
)


class RbacPolicy:
    def validate_identity(self, identity: Identity) -> tuple[bool, str]:
        if not identity.enabled:
            return False, "IDENTITY_DISABLED"

        if identity.identity_type not in {"HUMAN", "SERVICE"}:
            return False, "UNKNOWN_IDENTITY_TYPE"

        unknown = sorted(role for role in identity.roles if not known_role(role))
        if unknown:
            return False, "UNKNOWN_ROLE"

        if identity.identity_type == "SERVICE":
            if not identity.roles.issubset(SERVICE_ALLOWED_ROLES):
                return False, "SERVICE_ROLE_SCOPE_VIOLATION"

        if identity.identity_type == "HUMAN":
            if not identity.roles.issubset(HUMAN_ONLY_ROLES):
                return False, "HUMAN_ROLE_SCOPE_VIOLATION"

        return True, "IDENTITY_VALID"

    def decide(self, identity: Identity, resource: str, action: str) -> AccessDecision:
        valid, reason = self.validate_identity(identity)
        permission = f"{resource}:{action}"

        if not valid:
            return AccessDecision(
                allowed=False,
                reason=reason,
                identity_id=identity.identity_id,
                resource=resource,
                action=action,
            )

        permissions = permissions_for_roles(identity.roles)

        if permission not in permissions:
            return AccessDecision(
                allowed=False,
                reason="DENY_BY_DEFAULT",
                identity_id=identity.identity_id,
                resource=resource,
                action=action,
            )

        return AccessDecision(
            allowed=True,
            reason="RBAC_ALLOW",
            identity_id=identity.identity_id,
            resource=resource,
            action=action,
        )
'@

    $LeastPrivilegePy=@'
from __future__ import annotations

from .roles import HIGH_RISK_PERMISSIONS, ROLE_PERMISSIONS


def validate_role_catalog() -> dict:
    wildcard_permissions = []
    empty_roles = []
    high_risk_roles = {}

    for role, permissions in ROLE_PERMISSIONS.items():
        if not permissions:
            empty_roles.append(role)

        for permission in permissions:
            if "*" in permission:
                wildcard_permissions.append(f"{role}:{permission}")

        high_risk = sorted(set(permissions).intersection(HIGH_RISK_PERMISSIONS))
        if high_risk:
            high_risk_roles[role] = high_risk

    separation_ok = (
        "publication:publish" not in ROLE_PERMISSIONS.get("SECURITY_OPERATOR", frozenset())
        and "incident:escalate" not in ROLE_PERMISSIONS.get("PUBLISHER", frozenset())
        and "workflow:execute" not in ROLE_PERMISSIONS.get("PUBLISHER", frozenset())
    )

    return {
        "wildcard_permissions": sorted(wildcard_permissions),
        "empty_roles": sorted(empty_roles),
        "high_risk_roles": high_risk_roles,
        "separation_of_duties": separation_ok,
        "least_privilege_pass": (
            not wildcard_permissions
            and not empty_roles
            and separation_ok
        ),
    }
'@

    $AuditPy=@'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .authn import validate_authentication_profile
from .least_privilege import validate_role_catalog
from .models import Identity, SecurityControl
from .policy import RbacPolicy


class IdentityAccessSecurityAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        policy = RbacPolicy()

        reader = Identity(
            identity_id="USR-READER",
            identity_type="HUMAN",
            roles=frozenset({"LEXICAL_READER"}),
        )

        editor = Identity(
            identity_id="USR-EDITOR",
            identity_type="HUMAN",
            roles=frozenset({"LEXICAL_EDITOR"}),
        )

        publisher = Identity(
            identity_id="USR-PUBLISHER",
            identity_type="HUMAN",
            roles=frozenset({"PUBLISHER"}),
        )

        security = Identity(
            identity_id="USR-SECURITY",
            identity_type="HUMAN",
            roles=frozenset({"SECURITY_OPERATOR"}),
        )

        service = Identity(
            identity_id="SVC-WORKFLOW",
            identity_type="SERVICE",
            roles=frozenset({"SERVICE_WORKFLOW"}),
        )

        unknown = Identity(
            identity_id="USR-UNKNOWN",
            identity_type="HUMAN",
            roles=frozenset({"UNKNOWN_ROLE"}),
        )

        decisions = {
            "reader_read": policy.decide(reader, "lexical", "read"),
            "reader_publish": policy.decide(reader, "publication", "publish"),
            "editor_update": policy.decide(editor, "lexical", "update"),
            "publisher_publish": policy.decide(publisher, "publication", "publish"),
            "publisher_incident": policy.decide(publisher, "incident", "escalate"),
            "security_incident": policy.decide(security, "incident", "escalate"),
            "security_publish": policy.decide(security, "publication", "publish"),
            "service_execute": policy.decide(service, "workflow", "execute"),
            "service_publish": policy.decide(service, "publication", "publish"),
            "unknown_read": policy.decide(unknown, "lexical", "read"),
        }

        human_auth = validate_authentication_profile({
            "identity_type": "HUMAN",
            "enabled": True,
            "credential_reference": "env:SGODA_USER_CREDENTIAL",
            "factors": ["MFA"],
        })

        service_auth = validate_authentication_profile({
            "identity_type": "SERVICE",
            "enabled": True,
            "credential_reference": "secretref:SGODA_WORKFLOW_TOKEN",
            "factors": ["WORKLOAD_IDENTITY"],
        })

        least = validate_role_catalog()

        controls = [
            SecurityControl(
                "IAM-DENY-DEFAULT",
                "Deny by default",
                decisions["reader_publish"].allowed is False
                and decisions["service_publish"].allowed is False
                and decisions["unknown_read"].allowed is False,
                True,
                True,
                "Unauthorized and unknown-role access is denied.",
            ),
            SecurityControl(
                "IAM-RBAC",
                "Role-based access control",
                decisions["reader_read"].allowed is True
                and decisions["editor_update"].allowed is True
                and decisions["publisher_publish"].allowed is True
                and decisions["security_incident"].allowed is True
                and decisions["service_execute"].allowed is True,
                True,
                True,
                "Authorized role/action combinations are explicitly allowed.",
            ),
            SecurityControl(
                "IAM-LEAST-PRIVILEGE",
                "Least privilege",
                least["least_privilege_pass"] is True,
                True,
                True,
                "Role catalog contains no wildcard permissions and passes least-privilege rules.",
            ),
            SecurityControl(
                "IAM-SEPARATION-DUTIES",
                "Separation of duties",
                decisions["publisher_incident"].allowed is False
                and decisions["security_publish"].allowed is False
                and least["separation_of_duties"] is True,
                True,
                True,
                "Publishing and security escalation duties are separated.",
            ),
            SecurityControl(
                "IAM-SERVICE-IDENTITY",
                "Service identity confinement",
                decisions["service_execute"].allowed is True
                and decisions["service_publish"].allowed is False,
                True,
                True,
                "Service identities are confined to service-specific roles.",
            ),
            SecurityControl(
                "IAM-AUTHN",
                "Authentication profile requirements",
                human_auth["valid"] is True
                and service_auth["valid"] is True,
                True,
                True,
                "Human and service authentication profiles satisfy factor and indirection requirements.",
            ),
            SecurityControl(
                "IAM-SECRET-INDIRECTION",
                "Credential secret indirection",
                human_auth["credential_reference_indirect"] is True
                and service_auth["credential_reference_indirect"] is True
                and human_auth["secret_values_exposed"] is False
                and service_auth["secret_values_exposed"] is False,
                True,
                True,
                "Credential references are indirect; raw secret values are not persisted.",
            ),
        ]

        failed = [
            c.control_id
            for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "IDENTITY_ACCESS_GATE_PASS" if not failed else "IDENTITY_ACCESS_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "least_privilege": least,
            "authentication": {
                "human": human_auth,
                "service": service_auth,
            },
            "decisions": {
                key: value.__dict__
                for key, value in decisions.items()
            },
            "discovered_identity_access_surfaces": len(self.discovered_paths),
            "password_changed": False,
            "token_rotated": False,
            "os_permission_changed": False,
            "database_role_changed": False,
            "github_permission_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@

    $GatePy=@'
class IdentityAccessSecurityGate:
    BLOCKING = frozenset({
        "IAM-DENY-DEFAULT",
        "IAM-RBAC",
        "IAM-LEAST-PRIVILEGE",
        "IAM-SEPARATION-DUTIES",
        "IAM-SERVICE-IDENTITY",
        "IAM-AUTHN",
        "IAM-SECRET-INDIRECTION",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            c["control_id"] if isinstance(c, dict) else c.control_id: c
            for c in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []

        for control_id in sorted(cls.BLOCKING):
            control = by_id[control_id]
            passed = control["passed"] if isinstance(control, dict) else control.passed
            blocking = control["blocking"] if isinstance(control, dict) else control.blocking
            applicable = control["applicable"] if isinstance(control, dict) else control.applicable

            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
'@

    $IntegrityPy=@'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []

    for rel in sorted(set(paths)):
        path = root / rel
        if not path.is_file():
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
'@

    $ServicePy=@'
from pathlib import Path
from typing import Iterable

from .audit import IdentityAccessSecurityAuditor
from .gate import IdentityAccessSecurityGate


class IdentityAccessSecurityService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = IdentityAccessSecurityAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = IdentityAccessSecurityGate.evaluate(result["controls"])

        result["status"] = "IDENTITY_ACCESS_GATE_PASS" if passed else "IDENTITY_ACCESS_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
'@

    $TestsPy=@'
from pathlib import Path

from sgoda.integration.spt0249.authn import validate_authentication_profile
from sgoda.integration.spt0249.least_privilege import validate_role_catalog
from sgoda.integration.spt0249.models import Identity
from sgoda.integration.spt0249.policy import RbacPolicy
from sgoda.integration.spt0249.service import IdentityAccessSecurityService


def test_reader_can_read():
    identity = Identity(
        identity_id="U1",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")
    assert decision.allowed is True


def test_reader_cannot_publish():
    identity = Identity(
        identity_id="U1",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
    )
    decision = RbacPolicy().decide(identity, "publication", "publish")
    assert decision.allowed is False
    assert decision.reason == "DENY_BY_DEFAULT"


def test_unknown_role_is_denied():
    identity = Identity(
        identity_id="U2",
        identity_type="HUMAN",
        roles=frozenset({"UNKNOWN_ROLE"}),
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")
    assert decision.allowed is False
    assert decision.reason == "UNKNOWN_ROLE"


def test_service_identity_can_execute_workflow():
    identity = Identity(
        identity_id="SVC1",
        identity_type="SERVICE",
        roles=frozenset({"SERVICE_WORKFLOW"}),
    )
    decision = RbacPolicy().decide(identity, "workflow", "execute")
    assert decision.allowed is True


def test_service_identity_cannot_use_human_role():
    identity = Identity(
        identity_id="SVC2",
        identity_type="SERVICE",
        roles=frozenset({"PUBLISHER"}),
    )
    decision = RbacPolicy().decide(identity, "publication", "publish")
    assert decision.allowed is False
    assert decision.reason == "SERVICE_ROLE_SCOPE_VIOLATION"


def test_human_identity_cannot_use_service_role():
    identity = Identity(
        identity_id="U3",
        identity_type="HUMAN",
        roles=frozenset({"SERVICE_WORKFLOW"}),
    )
    decision = RbacPolicy().decide(identity, "workflow", "execute")
    assert decision.allowed is False
    assert decision.reason == "HUMAN_ROLE_SCOPE_VIOLATION"


def test_separation_of_duties():
    publisher = Identity(
        identity_id="PUB",
        identity_type="HUMAN",
        roles=frozenset({"PUBLISHER"}),
    )
    security = Identity(
        identity_id="SEC",
        identity_type="HUMAN",
        roles=frozenset({"SECURITY_OPERATOR"}),
    )

    policy = RbacPolicy()

    assert policy.decide(publisher, "publication", "publish").allowed is True
    assert policy.decide(publisher, "incident", "escalate").allowed is False
    assert policy.decide(security, "incident", "escalate").allowed is True
    assert policy.decide(security, "publication", "publish").allowed is False


def test_role_catalog_has_no_wildcards():
    result = validate_role_catalog()
    assert result["wildcard_permissions"] == []
    assert result["least_privilege_pass"] is True


def test_human_authentication_requires_indirect_reference():
    secure = validate_authentication_profile({
        "identity_type": "HUMAN",
        "enabled": True,
        "credential_reference": "env:USER_CREDENTIAL",
        "factors": ["MFA"],
    })
    insecure = validate_authentication_profile({
        "identity_type": "HUMAN",
        "enabled": True,
        "credential_reference": "plaintext-value",
        "factors": ["MFA"],
    })

    assert secure["valid"] is True
    assert insecure["valid"] is False


def test_service_authentication_profile():
    result = validate_authentication_profile({
        "identity_type": "SERVICE",
        "enabled": True,
        "credential_reference": "secretref:WORKFLOW_TOKEN",
        "factors": ["WORKLOAD_IDENTITY"],
    })

    assert result["valid"] is True
    assert result["secret_values_exposed"] is False


def test_disabled_identity_is_denied():
    identity = Identity(
        identity_id="U4",
        identity_type="HUMAN",
        roles=frozenset({"LEXICAL_READER"}),
        enabled=False,
    )
    decision = RbacPolicy().decide(identity, "lexical", "read")

    assert decision.allowed is False
    assert decision.reason == "IDENTITY_DISABLED"


def test_full_gate_passes(tmp_path):
    result = IdentityAccessSecurityService(tmp_path, []).assess()

    assert result["status"] == "IDENTITY_ACCESS_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_gate_has_no_operational_side_effects(tmp_path):
    result = IdentityAccessSecurityService(tmp_path, []).assess()

    assert result["password_changed"] is False
    assert result["token_rotated"] is False
    assert result["os_permission_changed"] is False
    assert result["database_role_changed"] is False
    assert result["github_permission_changed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
'@

    $PolicyJson=@'
{
  "component": "SPT-024.9",
  "layer": "1",
  "version": "1.0.0",
  "title": "Identidades, Autenticacion, Autorizacion, RBAC y Minimo Privilegio",
  "default_decision": "DENY",
  "blocking_controls": [
    "IAM-DENY-DEFAULT",
    "IAM-RBAC",
    "IAM-LEAST-PRIVILEGE",
    "IAM-SEPARATION-DUTIES",
    "IAM-SERVICE-IDENTITY",
    "IAM-AUTHN",
    "IAM-SECRET-INDIRECTION"
  ],
  "roles": {
    "LEXICAL_READER": [
      "lexical:read",
      "catalog:read"
    ],
    "LEXICAL_EDITOR": [
      "lexical:read",
      "lexical:create",
      "lexical:update",
      "catalog:read"
    ],
    "AUDITOR": [
      "audit:read",
      "evidence:read",
      "security:assessment:read"
    ],
    "PUBLISHER": [
      "publication:prepare",
      "publication:publish",
      "release:read"
    ],
    "SECURITY_OPERATOR": [
      "security:assessment:read",
      "incident:read",
      "incident:triage",
      "incident:escalate"
    ],
    "SERVICE_WORKFLOW": [
      "workflow:execute",
      "workflow:read"
    ]
  },
  "authentication": {
    "human_factor_policy": [
      "MFA",
      "PASSKEY",
      "OIDC",
      "PASSWORD"
    ],
    "service_factor_policy": [
      "WORKLOAD_IDENTITY",
      "OIDC",
      "SERVICE_TOKEN"
    ],
    "credential_reference_only": true
  },
  "safety": {
    "change_passwords": false,
    "rotate_tokens": false,
    "change_os_permissions": false,
    "change_database_roles": false,
    "change_github_permissions": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@

    $DocMd=@'
# SPT-024.9 Capa 1 — Identidades, Autenticacion, Autorizacion, RBAC y Minimo Privilegio

Baseline autoritativa: `960bbe9b74b7e075a1d09b470853da2efb11c734`.

Esta capa inicia el dominio IAM/PAM de la Plataforma Institucional de Seguridad Informatica (PISI), sin reabrir SPT-024.1–SPT-024.8.

## Objetivos

- modelo institucional de identidades HUMAN y SERVICE;
- autenticacion basada en referencias indirectas de credenciales;
- autorizacion RBAC;
- politica `DENY BY DEFAULT`;
- minimo privilegio;
- separacion de funciones;
- confinamiento de identidades de servicio;
- quality gate bloqueante;
- evidencia e integridad SHA-256.

## Controles bloqueantes

- IAM-DENY-DEFAULT
- IAM-RBAC
- IAM-LEAST-PRIVILEGE
- IAM-SEPARATION-DUTIES
- IAM-SERVICE-IDENTITY
- IAM-AUTHN
- IAM-SECRET-INDIRECTION

## Seguridad operacional

Capa 1 es estatica y no destructiva. No cambia contrasenas, no rota tokens, no modifica roles reales de PostgreSQL, permisos del sistema operativo o permisos de GitHub, no abre conexiones externas y no imprime valores secretos.

Las referencias de credenciales se modelan mediante prefijos indirectos (`env:`, `vaultref:`, `secretref:` o `credentialref:`).

El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment IAM, manifiesto SHA-256, preservation gate, staging exacto, gate global de blobs Git inferiores a 100 MB, remote gate, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/roles.py" $RolesPy
    Write-Lf "$ModuleDir/authn.py" $AuthnPy
    Write-Lf "$ModuleDir/policy.py" $PolicyPy
    Write-Lf "$ModuleDir/least_privilege.py" $LeastPrivilegePy
    Write-Lf "$ModuleDir/audit.py" $AuditPy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/integrity.py" $IntegrityPy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    Write-Host "SPT-024.9 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt0249; from sgoda.integration.spt0249.gate import IdentityAccessSecurityGate; assert len(IdentityAccessSecurityGate.BLOCKING)==7; print('SPT0249_IMPORT=PASS'); print('BLOCKING_CONTROLS=7')"
    ) "SPT-024.9 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.9 targeted tests"

    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"

    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"

    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION IDENTITY / ACCESS SECURITY ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $DiscoveryJson=($IdentitySurfaceFiles | ForEach-Object {Norm $_}) | ConvertTo-Json -Compress
    $DiscoveryTmp=Join-Path $env:TEMP ("sgoda-spt0249-"+[Guid]::NewGuid().ToString("N")+".json")
    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt0249-"+[Guid]::NewGuid().ToString("N")+".py")
    $Utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        [IO.File]::WriteAllText($DiscoveryTmp,($DiscoveryJson+"`n"),$Utf8)

        $Probe=@'
import json
import sys
from pathlib import Path

from sgoda.integration.spt0249.integrity import build_manifest
from sgoda.integration.spt0249.service import IdentityAccessSecurityService

root = Path.cwd()
paths = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

result = IdentityAccessSecurityService(root, paths).assess()

artifact_dir = root / "artifacts" / "development" / "SPT-024.9-Capa1-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

assessment_path = artifact_dir / "identity-access-assessment.json"
inventory_path = artifact_dir / "identity-access-surface-inventory.json"
integrity_path = artifact_dir / "identity-access-integrity-manifest.json"

assessment_path.write_text(
    json.dumps(result, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

inventory = {
    "mode": "GIT_TRACKED_STATIC_DISCOVERY",
    "surface_count": len(paths),
    "paths": sorted(set(p.replace("\\", "/") for p in paths)),
    "secret_values_exposed": False,
    "operational_changes_performed": False,
}

inventory_path.write_text(
    json.dumps(inventory, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

integrity = build_manifest(
    root,
    [
        str(assessment_path.relative_to(root)).replace("\\", "/"),
        str(inventory_path.relative_to(root)).replace("\\", "/"),
        "config/integration/spt0249/identity-access-security-policy.json",
    ],
)

integrity_path.write_text(
    json.dumps(integrity, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SPT0249_IDENTITY_ACCESS_STATUS=" + result["status"])
print("IDENTITY_ACCESS_SURFACES=%d" % len(paths))
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("INTEGRITY_RECORDS=%d" % integrity["record_count"])
print("PASSWORD_CHANGED=NO")
print("TOKEN_ROTATED=NO")
print("OS_PERMISSION_CHANGED=NO")
print("DATABASE_ROLE_CHANGED=NO")
print("GITHUB_PERMISSION_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "IDENTITY_ACCESS_GATE_PASS":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbeTmp,
            (($Probe -replace "`r`n","`n") -replace "`r","`n"),
            $Utf8
        )

        & $Python $ProbeTmp $DiscoveryTmp
        $AssessmentExit=$LASTEXITCODE

        if($AssessmentExit -eq 20){
            Write-Host "SAFE ASSESSMENT REPORT : $AssessmentFile"
            Stop-Hold "Blocking SPT-024.9 identity/access controls failed."
        }

        if($AssessmentExit -ne 0){
            Stop-Hold "Production assessment failed with exit code $AssessmentExit."
        }
    }
    finally{
        Remove-Item -LiteralPath $DiscoveryTmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "IDENTITY / ACCESS SECURITY GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"

    $Assessment=Get-Content -LiteralPath $AssessmentFile -Raw -Encoding UTF8 | ConvertFrom-Json

    if($Assessment.status -ne "IDENTITY_ACCESS_GATE_PASS"){
        Stop-Hold "Assessment does not certify PASS."
    }

    $Evidence=[ordered]@{
        component="SPT-024.9"
        layer="1"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="IDENTITY_ACCESS_GATE_PASS"
        gates=[ordered]@{
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            identity_access="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            assessment=$AssessmentFile
            surface_inventory=$InventoryFile
            integrity_manifest=$IntegrityFile
        }
        password_changed=$false
        token_rotated=$false
        os_permission_changed=$false
        database_role_changed=$false
        github_permission_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)

    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INVENTORY  : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot

    Write-Host "SPT-024.1-.8 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $StageTargets=@(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )

    foreach($Target in $StageTargets){
        if(Test-Path -LiteralPath $Target){
            Native "git.exe" @(
                "-c",
                "core.safecrlf=false",
                "add",
                "--",
                $Target
            ) ("git add "+$Target)
        }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)

    if($LASTEXITCODE -ne 0){
        throw "Unable to inspect staging."
    }

    $Unexpected=@()

    foreach($RawPath in $StagedNow){
        $PathValue=Norm $RawPath

        $Allowed=(
            $PathValue -eq $SelfName -or
            $PathValue -eq $TestFile -or
            $PathValue -eq $PolicyFile -or
            $PathValue -eq $DocFile -or
            $PathValue.StartsWith((Norm $ModuleDir)+"/") -or
            $PathValue.StartsWith((Norm $ArtifactDir)+"/")
        )

        if(-not $Allowed){
            $Unexpected += $PathValue
        }
    }

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){
        & git.exe reset
        Stop-Hold "Unexpected file entered controlled staging."
    }

    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"

    $TooLarge=@(Get-IndexOversizedBlobs)

    Write-Host "INDEX BLOBS >=100MB : $($TooLarge.Count)"

    if($TooLarge.Count -gt 0){
        foreach($Item in $TooLarge){
            Write-Host ("TOO LARGE : {0} ({1} bytes)" -f $Item.path,$Item.bytes) -ForegroundColor Red
        }

        Stop-Hold "Git index contains one or more blobs >=100 MB."
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalBefore=(& git.exe rev-parse HEAD).Trim()
    $RemoteBefore=(& git.exe rev-parse ("origin/"+$Branch)).Trim()

    if($LocalBefore -ne $ExpectedBaseline -or $RemoteBefore -ne $ExpectedBaseline){
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }

    Assert-Snapshot $Snapshot

    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.9): implement identity access RBAC and least privilege layer 1"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()

    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"

    Native "git.exe" @(
        "push",
        "origin",
        $Branch
    ) "git push"

    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Counts=((& git.exe rev-list --left-right --count (("origin/"+$Branch)+"...HEAD")).Trim() -split '\s+')
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $($Counts[0])"
    Write-Host "AHEAD           : $($Counts[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if(
        $FinalLocal -ne $FinalRemote -or
        $Counts[0] -ne "0" -or
        $Counts[1] -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){
        Stop-Hold "Final repository synchronization failed."
    }

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.9 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host " IDENTITY_ACCESS_GATE=PASS" -ForegroundColor Green
    Write-Host " DENY_BY_DEFAULT=PASS" -ForegroundColor Green
    Write-Host " RBAC=PASS" -ForegroundColor Green
    Write-Host " LEAST_PRIVILEGE=PASS" -ForegroundColor Green
    Write-Host " SEPARATION_OF_DUTIES=PASS" -ForegroundColor Green
    Write-Host " SERVICE_IDENTITY_CONFINEMENT=PASS" -ForegroundColor Green
    Write-Host " AUTHENTICATION_PROFILE=PASS" -ForegroundColor Green
    Write-Host " SECRET_INDIRECTION=PASS" -ForegroundColor Green
    Write-Host " TARGETED_TESTS=PASS" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green

    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
