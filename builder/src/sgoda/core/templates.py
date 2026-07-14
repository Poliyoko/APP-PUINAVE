import json


def build_project_files(project_name: str) -> dict[str, str]:
    manifest = {
        "schema_version": "1.1",
        "project": {"name": project_name, "type": "SGODA"},
        "components": {},
    }
    return {
        "README.md": f"# {project_name}\n",
        ".gitignore": "__pycache__/\n",
        "sgoda.project.json": json.dumps(
            manifest, ensure_ascii=False, indent=2
        ) + "\n",
        "data/json/palabras.json": '{"records": []}\n',
    }
