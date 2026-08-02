"""CLI institucional de SGD-114C."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .policy_context import PolicyContext
from .policy_engine import evaluate_policy
from .policy_registry import build_default_registry
from .policy_report import write_reports


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    policy = json.loads(
        Path(args.policy).read_text(encoding="utf-8-sig")
    )

    context = PolicyContext(
        root=root,
        increment=args.increment,
        policy=policy,
    )

    evaluation = evaluate_policy(
        context,
        build_default_registry(),
    )

    write_reports(
        evaluation,
        args.output_json,
        args.output_md,
    )

    print("Policy Governance Core ejecutado.")
    print("Política:", evaluation.policy_code, evaluation.policy_version)
    print("Incremento:", evaluation.increment)
    print(
        "Resultado:",
        "APROBADO" if evaluation.approved else "NO APROBADO",
    )
    print("Código de salida:", evaluation.exit_code)
    print("Bloqueantes:", len(evaluation.blocking_rules))
    print("JSON:", args.output_json)
    print("Markdown:", args.output_md)

    return evaluation.exit_code


if __name__ == "__main__":
    raise SystemExit(main())