from __future__ import annotations
import re
from pathlib import Path
from typing import Dict, List


class WorkflowAudit:
    ACTION_RE = re.compile(r"(?m)^\s*-\s*uses:\s*([^\s#]+)")
    RUN_LINE_RE = re.compile(r"(?m)^\s*(?:-\s*)?run:\s*(.+)$")
    WRITE_ALL_RE = re.compile(r"(?im)^\s*permissions:\s*write-all\s*$")
    DIRECT_SECRET_RE = re.compile(r"\$\{\{\s*secrets\.[A-Za-z0-9_]+\s*\}\}")
    EVENT_INTERPOLATION_RE = re.compile(r"\$\{\{\s*github\.event\.[^}]+\}\}")
    DANGEROUS_SHELL_RE = re.compile(
        r"(?i)(curl\s+[^|\r\n]+\|\s*(?:bash|sh)|wget\s+[^|\r\n]+\|\s*(?:bash|sh)|"
        r"\bInvoke-Expression\b|\biex\b|\beval\s+)"
    )

    @staticmethod
    def _read(root: Path, rel: str) -> str:
        try:
            return (root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    @classmethod
    def assess(cls, root: Path, paths: List[str]) -> Dict[str, object]:
        floating_actions: List[str] = []
        mutable_branch_actions: List[str] = []
        broad_permissions: List[str] = []
        direct_secret_shell: List[str] = []
        expression_injection: List[str] = []
        dangerous_shell: List[str] = []
        action_refs: List[dict] = []

        for rel in paths:
            text = cls._read(root, rel)

            if cls.WRITE_ALL_RE.search(text):
                broad_permissions.append(rel)

            for match in cls.ACTION_RE.finditer(text):
                ref = match.group(1).strip()
                action_refs.append({"workflow": rel, "ref": ref})

                if "@" not in ref:
                    floating_actions.append(f"{rel}:{ref}")
                    continue

                _, version = ref.rsplit("@", 1)
                vlow = version.lower()
                if vlow in {"main", "master", "latest", "head", "develop", "dev"}:
                    mutable_branch_actions.append(f"{rel}:{ref}")
                elif not re.fullmatch(r"[0-9a-fA-F]{40}", version):
                    floating_actions.append(f"{rel}:{ref}")

            for line in cls.RUN_LINE_RE.findall(text):
                if cls.DIRECT_SECRET_RE.search(line):
                    direct_secret_shell.append(rel)
                if cls.EVENT_INTERPOLATION_RE.search(line):
                    expression_injection.append(rel)
                if cls.DANGEROUS_SHELL_RE.search(line):
                    dangerous_shell.append(rel)

        return {
            "action_refs": action_refs,
            "floating_actions": sorted(set(floating_actions)),
            "mutable_branch_actions": sorted(set(mutable_branch_actions)),
            "broad_permissions": sorted(set(broad_permissions)),
            "direct_secret_shell": sorted(set(direct_secret_shell)),
            "expression_injection": sorted(set(expression_injection)),
            "dangerous_shell": sorted(set(dangerous_shell)),
        }
