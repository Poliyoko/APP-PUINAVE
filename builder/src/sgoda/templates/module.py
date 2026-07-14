import re
import unicodedata


def normalize_module_name(name: str) -> str:
    value = unicodedata.normalize("NFKD", name)
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = re.sub(r"[^a-zA-Z0-9_]+", "_", value.lower()).strip("_")
    if not value:
        raise ValueError("Nombre inválido")
    return value


def build_module_files(name: str) -> dict[str, str]:
    normalized = normalize_module_name(name)
    return {f"modules/{normalized}/README.md": f"# {normalized}\n"}
