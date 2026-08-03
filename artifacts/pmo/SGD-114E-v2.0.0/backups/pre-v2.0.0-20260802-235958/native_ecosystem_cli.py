from __future__ import annotations
import argparse, json
from pathlib import Path
from .native_ecosystem_validator import evaluate_native_ecosystem

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
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    md_target.write_text(
        "\n".join([
            "# SGD-114E — Native Ecosystem Validation",
            "",
            f"- Contrato mapping: {result['version']}",
            f"- Contrato atributo: {result['attribute_version']}",
            f"- Implementación: {result['implementation_version']}",
            f"- Resultado: {result['result']}",
            f"- Exit code: {result['exit_code']}",
            f"- Componentes nativos: {result['native_component_count']}",
            f"- Hallazgos: {len(result['findings'])}",
            "",
        ]),
        encoding="utf-8",
    )
    print("SGD-114E ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(f"Contrato mapping: {result['version']}")
    print(f"Contrato atributo: {result['attribute_version']}")
    print(f"Implementación: {result['implementation_version']}")
    print(f"Exit code: {result['exit_code']}")
    return validation.exit_code

if __name__ == "__main__":
    raise SystemExit(main())