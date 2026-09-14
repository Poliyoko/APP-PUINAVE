from __future__ import annotations

import sys
from pathlib import Path


IMPORT_LINE = (
    "import 'demo25_external_resource_links.g.dart';"
)

OLD_IMPORT_ANCHOR = (
    "import 'demo25_ui_closure_support.g.dart';"
)

OLD_BLOCK = """          final configuredUrl = (resource?['url'] ?? '').trim();

          final url = type == 'BIBLE' && configuredUrl.isEmpty
              ? demo25VerifiedBibleUrl
              : configuredUrl;

          final canOpen =
              url.startsWith('https://') || url.startsWith('http://');
"""

NEW_BLOCK = """          final resourceId = (resource?['id'] ?? '').trim();

          final publicLinks = resourceId.isEmpty
              ? const <Demo25ExternalResourceLink>[]
              : demo25PublicLinksForResource(resourceId);

          // Compatibility fallback while legacy single-URL resources
          // are migrated to the universal 0..N link contract.
          final configuredUrl = (resource?['url'] ?? '').trim();

          final legacyUrl = type == 'BIBLE' && configuredUrl.isEmpty
              ? demo25VerifiedBibleUrl
              : configuredUrl;

          final legacyCanOpen =
              legacyUrl.startsWith('https://') ||
              legacyUrl.startsWith('http://');

          final useLegacyFallback =
              publicLinks.isEmpty && legacyCanOpen;
"""

OLD_BUTTON = """                  final button = canOpen
                      ? FilledButton.tonalIcon(
                          onPressed: () async {
                            final opened = await openExternalUrl(url);

                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'El enlace '
                                    'no pudo '
                                    'abrirse en '
                                    'esta '
                                    'plataforma.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir'),
                        )
                      : null;
"""

NEW_BUTTON = """                  Future<void> openLink(
                    String url,
                  ) async {
                    final opened = await openExternalUrl(url);

                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El enlace no pudo abrirse '
                            'en esta plataforma.',
                          ),
                        ),
                      );
                    }
                  }

                  final linkButtons = <Widget>[
                    ...publicLinks.map(
                      (link) => FilledButton.tonalIcon(
                        onPressed: () => openLink(link.url),
                        icon: Icon(
                          link.type == 'AUDIO'
                              ? Icons.audiotrack_outlined
                              : link.type == 'VIDEO'
                                  ? Icons.play_circle_outline
                                  : link.type == 'DOCUMENT' ||
                                          link.type == 'DOWNLOAD'
                                      ? Icons.description_outlined
                                      : link.type == 'ANDROID_APP' ||
                                              link.type == 'IOS_APP'
                                          ? Icons.phone_android_outlined
                                          : Icons.open_in_new,
                        ),
                        label: Text(link.label),
                      ),
                    ),
                    if (useLegacyFallback)
                      FilledButton.tonalIcon(
                        onPressed: () => openLink(legacyUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir'),
                      ),
                  ];

                  final buttons = linkButtons.isEmpty
                      ? null
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: linkButtons,
                        );
"""

OLD_NARROW = """                        if (button != null) ...[
                          const SizedBox(height: 14),
                          Align(alignment: Alignment.centerLeft, child: button),
                        ],
"""

NEW_NARROW = """                        if (buttons != null) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: buttons,
                          ),
                        ],
"""

OLD_WIDE = """                      if (button != null) ...[
                        const SizedBox(width: 16),
                        button,
                      ],
"""

NEW_WIDE = """                      if (buttons != null) ...[
                        const SizedBox(width: 16),
                        Flexible(child: buttons),
                      ],
"""


def count(text: str, token: str) -> int:
    return text.count(token)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patcher.py <main.dart>")

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    # ------------------------------------------------------------
    # Import - idempotent
    # ------------------------------------------------------------

    if IMPORT_LINE not in text:
        if OLD_IMPORT_ANCHOR not in text:
            raise RuntimeError("IMPORT_ANCHOR_NOT_FOUND")

        text = text.replace(
            OLD_IMPORT_ANCHOR,
            OLD_IMPORT_ANCHOR + "\n" + IMPORT_LINE,
            1,
        )

    if count(text, IMPORT_LINE) != 1:
        raise RuntimeError(
            f"MULTILINK_IMPORT_COUNT={count(text, IMPORT_LINE)}"
        )

    # ------------------------------------------------------------
    # URL resolution block
    # ------------------------------------------------------------

    if NEW_BLOCK not in text:
        if count(text, OLD_BLOCK) != 1:
            raise RuntimeError(
                "LEGACY_URL_BLOCK_NOT_EXACTLY_ONE"
            )

        text = text.replace(
            OLD_BLOCK,
            NEW_BLOCK,
            1,
        )

    # ------------------------------------------------------------
    # Button renderer
    # ------------------------------------------------------------

    if NEW_BUTTON not in text:
        if count(text, OLD_BUTTON) != 1:
            raise RuntimeError(
                "LEGACY_BUTTON_BLOCK_NOT_EXACTLY_ONE"
            )

        text = text.replace(
            OLD_BUTTON,
            NEW_BUTTON,
            1,
        )

    # ------------------------------------------------------------
    # Responsive bindings
    # ------------------------------------------------------------

    if NEW_NARROW not in text:
        if count(text, OLD_NARROW) != 1:
            raise RuntimeError(
                "LEGACY_NARROW_BINDING_NOT_EXACTLY_ONE"
            )

        text = text.replace(
            OLD_NARROW,
            NEW_NARROW,
            1,
        )

    if NEW_WIDE not in text:
        if count(text, OLD_WIDE) != 1:
            raise RuntimeError(
                "LEGACY_WIDE_BINDING_NOT_EXACTLY_ONE"
            )

        text = text.replace(
            OLD_WIDE,
            NEW_WIDE,
            1,
        )

    # ------------------------------------------------------------
    # Contract assertions
    # ------------------------------------------------------------

    required = [
        IMPORT_LINE,
        "demo25PublicLinksForResource(resourceId)",
        "const <Demo25ExternalResourceLink>[]",
        "publicLinks.map(",
        "link.label",
        "link.url",
        "useLegacyFallback",
        "final buttons = linkButtons.isEmpty",
        "Flexible(child: buttons)",
    ]

    for token in required:
        if token not in text:
            raise RuntimeError(
                f"PATCH_CONTRACT_MISSING={token}"
            )

    forbidden = [
        "final button = canOpen",
    ]

    for token in forbidden:
        if token in text:
            raise RuntimeError(
                f"LEGACY_RENDERER_REMAINS={token}"
            )

    path.write_text(text, encoding="utf-8")

    print("MULTILINK_IMPORT=PASS")
    print("PUBLIC_LINK_LOOKUP=PASS")
    print("DYNAMIC_BUTTON_RENDERER=PASS")
    print("RESPONSIVE_WRAP=PASS")
    print("LEGACY_SINGLE_URL_FALLBACK=PRESERVED")
    print("PATCH=PASS")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())