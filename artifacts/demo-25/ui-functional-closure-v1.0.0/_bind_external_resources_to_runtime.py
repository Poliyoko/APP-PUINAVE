from pathlib import Path
import json
import re
import sys

runtime_path = Path(sys.argv[1])
config_path = Path(sys.argv[2])

runtime = runtime_path.read_text(encoding="utf-8")
config = json.loads(
    config_path.read_text(encoding="utf-8")
)


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)

    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


resources = {}

for item in walk(config):
    if not isinstance(item, dict):
        continue

    resource_id = str(
        item.get("id") or ""
    ).strip()

    if resource_id:
        resources[resource_id] = item


def external_fields(resource):
    source = resource.get("source")
    url = ""

    if isinstance(source, dict):
        if str(
            source.get("mode") or ""
        ).strip().lower() == "url":
            url = str(
                source.get("url") or ""
            ).strip()

    if not url:
        url = str(
            resource.get("url") or ""
        ).strip()

    visible = resource.get(
        "visible_link",
        False,
    )

    if isinstance(visible, str):
        visible = (
            visible.strip().lower()
            in {"true", "1", "yes", "on"}
        )
    else:
        visible = bool(visible)

    status = str(
        resource.get("status") or ""
    ).strip().upper()

    if status != "VERIFIED":
        return "", False

    if not visible:
        return "", False

    if not (
        url.startswith("https://")
        or url.startswith("http://")
    ):
        return "", False

    return url, True


def dart_escape(value):
    return (
        value
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\r", "")
        .replace("\n", "\\n")
    )


list_match = re.search(
    r"(const\s+demo25LibraryResources"
    r"\s*=\s*<Map<String,\s*String>>\[)"
    r"(.*?)"
    r"(\];)",
    runtime,
    re.DOTALL,
)

if list_match is None:
    raise RuntimeError(
        "RUNTIME_LIBRARY_LIST_NOT_FOUND"
    )

body = list_match.group(2)

blocks = list(
    re.finditer(
        r"\{\s*"
        r"'id'\s*:\s*'([^']+)'"
        r".*?"
        r"'url'\s*:\s*'[^']*'\s*,?"
        r"\s*\}",
        body,
        re.DOTALL,
    )
)

if not blocks:
    raise RuntimeError(
        "RUNTIME_RESOURCE_BLOCKS_NOT_FOUND"
    )

reconciled = 0
output = []
cursor = 0

for match in blocks:
    output.append(
        body[cursor:match.start()]
    )

    block = match.group(0)
    resource_id = match.group(1)

    resource = resources.get(resource_id)

    if resource is not None:
        url, visible = external_fields(
            resource
        )

        visible_text = (
            "true" if visible else "false"
        )

        block = re.sub(
            r"'visible'\s*:\s*'(?:true|false)'",
            "'visible': '"
            + visible_text
            + "'",
            block,
            count=1,
        )

        block = re.sub(
            r"'url'\s*:\s*'[^']*'",
            "'url': '"
            + dart_escape(url)
            + "'",
            block,
            count=1,
        )

        reconciled += 1

    output.append(block)
    cursor = match.end()

output.append(body[cursor:])

new_body = "".join(output)

runtime = (
    runtime[:list_match.start(2)]
    + new_body
    + runtime[list_match.end(2):]
)

runtime_path.write_text(
    runtime,
    encoding="utf-8",
    newline="\n",
)

print(
    "RUNTIME_RESOURCE_BLOCKS="
    + str(len(blocks))
)

print(
    "RUNTIME_EXTERNAL_RESOURCES_RECONCILED="
    + str(reconciled)
)

if reconciled < 1:
    raise RuntimeError(
        "NO_EXTERNAL_RESOURCES_RECONCILED"
    )
