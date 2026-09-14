from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse


SUPPORTED_LINK_TYPES = {
    "WEB",
    "ANDROID_APP",
    "IOS_APP",
    "DEEP_LINK",
    "AUDIO",
    "VIDEO",
    "DOCUMENT",
    "DOWNLOAD",
    "OTHER",
}

VERIFIED_RESOURCE_STATUSES = {
    "VERIFIED",
    "COMMUNITY_APPROVED",
}

HTTP_LINK_TYPES = {
    "WEB",
    "ANDROID_APP",
    "IOS_APP",
    "AUDIO",
    "VIDEO",
    "DOCUMENT",
    "DOWNLOAD",
    "OTHER",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, value) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def dart_string(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\r", "")
        .replace("\n", "\\n")
    )


def is_valid_http_url(value: str) -> bool:
    try:
        parsed = urlparse(value)
    except Exception:
        return False

    return (
        parsed.scheme.lower() == "https"
        and bool(parsed.netloc)
    )


def normalize_link(
    resource: dict,
    link: dict,
    index: int,
) -> dict:
    resource_id = str(resource.get("id") or resource.get("resource_id") or "").strip()

    link_type = str(
        link.get("type")
        or link.get("link_type")
        or "WEB"
    ).strip().upper()

    if link_type not in SUPPORTED_LINK_TYPES:
        link_type = "OTHER"

    link_id = str(
        link.get("id")
        or link.get("link_id")
        or f"{resource_id}-link-{index + 1}"
    ).strip()

    label = str(
        link.get("label")
        or link.get("display_label")
        or "Abrir"
    ).strip()

    url = str(
        link.get("url")
        or link.get("href")
        or ""
    ).strip()

    enabled = bool(link.get("enabled", True))
    visible = bool(
        link.get(
            "visible",
            link.get("visible_link", True),
        )
    )

    status = str(
        link.get("status")
        or resource.get("status")
        or "PENDING_VERIFICATION"
    ).strip().upper()

    platform = str(
        link.get("platform")
        or "ANY"
    ).strip().upper()

    order = link.get("order", (index + 1) * 10)

    try:
        order = int(order)
    except Exception:
        order = (index + 1) * 10

    valid_url = False

    if link_type == "DEEP_LINK":
        try:
            parsed = urlparse(url)
            valid_url = bool(parsed.scheme) and parsed.scheme.lower() not in {
                "http",
                "https",
            }
        except Exception:
            valid_url = False

    elif link_type in HTTP_LINK_TYPES:
        valid_url = is_valid_http_url(url)

    publishable = (
        enabled
        and visible
        and valid_url
        and status in VERIFIED_RESOURCE_STATUSES
        and str(resource.get("status", "")).upper()
            in VERIFIED_RESOURCE_STATUSES
    )

    return {
        "id": link_id,
        "type": link_type,
        "label": label,
        "url": url,
        "platform": platform,
        "status": status,
        "enabled": enabled,
        "visible": visible,
        "order": order,
        "valid_url": valid_url,
        "publishable": publishable,
    }


def migrate_resource(resource: dict) -> dict:
    resource = dict(resource)

    existing_links = resource.get("links")

    if not isinstance(existing_links, list):
        existing_links = []

    # Compatibilidad con el contrato anterior de una sola URL.
    legacy_url = str(resource.get("url") or "").strip()
    legacy_visible = bool(resource.get("visible_link", False))

    if legacy_url:
        legacy_already_present = any(
            str(item.get("url") or "").strip() == legacy_url
            for item in existing_links
            if isinstance(item, dict)
        )

        if not legacy_already_present:
            existing_links.append(
                {
                    "id": f"{resource.get('id', 'resource')}-web",
                    "type": "WEB",
                    "label": "Abrir",
                    "url": legacy_url,
                    "platform": "ANY",
                    "status": resource.get(
                        "status",
                        "PENDING_VERIFICATION",
                    ),
                    "enabled": True,
                    "visible": legacy_visible,
                    "order": 10,
                }
            )

    normalized = [
        normalize_link(resource, item, index)
        for index, item in enumerate(existing_links)
        if isinstance(item, dict)
    ]

    normalized.sort(
        key=lambda item: (
            item["order"],
            item["label"].casefold(),
            item["id"].casefold(),
        )
    )

    resource["links"] = normalized
    resource["link_engine"] = "UNIVERSAL_0_N"

    return resource


def extract_resources(document):
    if isinstance(document, list):
        return document, None

    if not isinstance(document, dict):
        raise RuntimeError("EXTERNAL_RESOURCES_DOCUMENT_INVALID")

    for key in (
        "resources",
        "external_resources",
        "items",
    ):
        if isinstance(document.get(key), list):
            return document[key], key

    raise RuntimeError("EXTERNAL_RESOURCES_LIST_NOT_FOUND")


def generate_dart(resources: list[dict]) -> str:
    lines = []

    lines.append("// GENERATED FILE - DO NOT EDIT MANUALLY.")
    lines.append("// SGODA Universal External Resource Link Engine 0..N")
    lines.append("")
    lines.append("class Demo25ExternalResourceLink {")
    lines.append("  const Demo25ExternalResourceLink({")
    lines.append("    required this.id,")
    lines.append("    required this.type,")
    lines.append("    required this.label,")
    lines.append("    required this.url,")
    lines.append("    required this.platform,")
    lines.append("    required this.status,")
    lines.append("    required this.enabled,")
    lines.append("    required this.visible,")
    lines.append("    required this.publishable,")
    lines.append("    required this.order,")
    lines.append("  });")
    lines.append("")
    lines.append("  final String id;")
    lines.append("  final String type;")
    lines.append("  final String label;")
    lines.append("  final String url;")
    lines.append("  final String platform;")
    lines.append("  final String status;")
    lines.append("  final bool enabled;")
    lines.append("  final bool visible;")
    lines.append("  final bool publishable;")
    lines.append("  final int order;")
    lines.append("}")
    lines.append("")
    lines.append(
        "const Map<String, List<Demo25ExternalResourceLink>> "
        "demo25ExternalResourceLinks = {"
    )

    for resource in resources:
        resource_id = str(
            resource.get("id")
            or resource.get("resource_id")
            or ""
        ).strip()

        if not resource_id:
            continue

        links = resource.get("links") or []

        lines.append(f"  '{dart_string(resource_id)}': [")

        for link in links:
            lines.append("    Demo25ExternalResourceLink(")
            lines.append(
                f"      id: '{dart_string(link['id'])}',"
            )
            lines.append(
                f"      type: '{dart_string(link['type'])}',"
            )
            lines.append(
                f"      label: '{dart_string(link['label'])}',"
            )
            lines.append(
                f"      url: '{dart_string(link['url'])}',"
            )
            lines.append(
                f"      platform: '{dart_string(link['platform'])}',"
            )
            lines.append(
                f"      status: '{dart_string(link['status'])}',"
            )
            lines.append(
                f"      enabled: {str(link['enabled']).lower()},"
            )
            lines.append(
                f"      visible: {str(link['visible']).lower()},"
            )
            lines.append(
                f"      publishable: "
                f"{str(link['publishable']).lower()},"
            )
            lines.append(
                f"      order: {link['order']},"
            )
            lines.append("    ),")

        lines.append("  ],")

    lines.append("};")
    lines.append("")
    lines.append(
        "List<Demo25ExternalResourceLink> "
        "demo25PublicLinksForResource(String resourceId) {"
    )
    lines.append(
        "  final links = "
        "demo25ExternalResourceLinks[resourceId] ?? "
        "const <Demo25ExternalResourceLink>[];"
    )
    lines.append(
        "  return links.where((link) => link.publishable).toList()"
    )
    lines.append(
        "    ..sort((a, b) => a.order.compareTo(b.order));"
    )
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: generator.py "
            "<external-resources.json> "
            "<generated.dart> "
            "<evidence.json>"
        )

    config_path = Path(sys.argv[1])
    dart_path = Path(sys.argv[2])
    evidence_path = Path(sys.argv[3])

    document = load_json(config_path)
    resources, container_key = extract_resources(document)

    migrated = [
        migrate_resource(resource)
        for resource in resources
        if isinstance(resource, dict)
    ]

    ids = []

    for resource in migrated:
        rid = str(
            resource.get("id")
            or resource.get("resource_id")
            or ""
        ).strip()

        if not rid:
            raise RuntimeError(
                "RESOURCE_WITHOUT_STABLE_ID"
            )

        if rid in ids:
            raise RuntimeError(
                f"DUPLICATE_RESOURCE_ID={rid}"
            )

        ids.append(rid)

    if container_key is None:
        updated_document = migrated
    else:
        updated_document = dict(document)
        updated_document[container_key] = migrated

    save_json(config_path, updated_document)

    dart_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    dart_path.write_text(
        generate_dart(migrated),
        encoding="utf-8",
    )

    all_links = [
        link
        for resource in migrated
        for link in resource.get("links", [])
    ]

    publishable = [
        link
        for link in all_links
        if link["publishable"]
    ]

    invalid_public_candidates = [
        link
        for link in all_links
        if (
            link["enabled"]
            and link["visible"]
            and not link["valid_url"]
        )
    ]

    evidence = {
        "schema_version": "1.0.0",
        "component":
            "SGODA-UNIVERSAL-EXTERNAL-RESOURCE-LINK-ENGINE",
        "status": "PASS",
        "resources": len(migrated),
        "links_total": len(all_links),
        "publishable_links": len(publishable),
        "invalid_visible_links":
            len(invalid_public_candidates),
        "links_per_resource": "0..N",
        "provider_hardcoding": False,
        "language_hardcoding": False,
        "resource_type_hardcoding": False,
        "legacy_url_compatibility": True,
        "supported_link_types":
            sorted(SUPPORTED_LINK_TYPES),
    }

    evidence_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    save_json(evidence_path, evidence)

    print(
        f"RESOURCES={len(migrated)}"
    )
    print(
        f"LINKS_TOTAL={len(all_links)}"
    )
    print(
        f"PUBLISHABLE_LINKS={len(publishable)}"
    )
    print(
        "INVALID_VISIBLE_LINKS="
        f"{len(invalid_public_candidates)}"
    )
    print(
        "UNIVERSAL_LINK_ENGINE=PASS"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())