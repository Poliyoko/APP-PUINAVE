from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    validation = evaluate_native_ecosystem(args.root)
    result = validation.to_dict()

    json_target = Path(args.output_json)
    md_target = Path(args.output_md)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    md_target.write_text(
        "\n".join(
            [
                "# SGD-114E v2.0.0",
                "",
                f"- Resultado: {result['result']}",
                f"- Exit code: {result['exit_code']}",
                f"- Mapping contract: {result['version']}",
                f"- Attribute contract: {result['attribute_version']}",
                f"- Implementation: {result['implementation_version']}",
                f"- Repository empty: {result['repository_is_empty']}",
                f"- Native components: {result['native_component_count']}",
                f"- Findings: {len(result['findings'])}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print("SGD-114E v2.0.0 ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(f"Exit code: {result['exit_code']}")
    print(f"Implementación: {result['implementation_version']}")

    return validation.exit_code


if __name__ == "__main__":
    raise SystemExit(main())