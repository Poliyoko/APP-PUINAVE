from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# DEMO25_UNIVERSAL_EXTERNAL_LINK_ENGINE_BEGIN
def _demo25_external_link_fields(resource):
    """
    Generic SGODA external-resource runtime binding.

    Contract:
      source.mode=url + source.url OR top-level url
      visible_link controls runtime visibility.

    No resource type, language or provider is hardcoded here.
    """
    if not isinstance(resource, dict):
        return "", False

    source = resource.get("source")
    source_url = ""

    if isinstance(source, dict):
        mode = str(source.get("mode") or "").strip().lower()
        if mode == "url":
            source_url = str(source.get("url") or "").strip()

    direct_url = str(resource.get("url") or "").strip()
    url = source_url or direct_url

    visible_link = resource.get("visible_link", False)

    if isinstance(visible_link, str):
        visible_link = visible_link.strip().lower() in {
            "1", "true", "yes", "on"
        }
    else:
        visible_link = bool(visible_link)

    if not (url.startswith("https://") or url.startswith("http://")):
        url = ""
        visible_link = False

    return url, visible_link
# DEMO25_UNIVERSAL_EXTERNAL_LINK_ENGINE_END


repo = Path(sys.argv[1]).resolve()
app = repo / "apps" / "sgoda_puinave_demo"

main_path = app / "lib" / "main.dart"
support_path = app / "lib" / "demo25_ui_closure_support.g.dart"

instance_path = (
    repo
    / "config"
    / "demo25"
    / "instances"
    / "puinave"
    / "instance-config.json"
)

android_manifest_path = (
    app
    / "android"
    / "app"
    / "src"
    / "main"
    / "AndroidManifest.xml"
)

web_index_path = app / "web" / "index.html"
web_manifest_path = app / "web" / "manifest.json"


def read_json(path: Path):
    return json.loads(
        path.read_text(
            encoding="utf-8-sig",
        )
    )


def class_span(
    text: str,
    class_name: str,
) -> tuple[int, int]:

    token = "class " + class_name

    start = text.find(token)

    if start < 0:
        raise RuntimeError(
            "CLASS_NOT_FOUND=" + class_name
        )

    brace = text.find("{", start)

    if brace < 0:
        raise RuntimeError(
            "CLASS_OPEN_BRACE_NOT_FOUND="
            + class_name
        )

    depth = 0
    i = brace

    while i < len(text):

        ch = text[i]

        if ch == "{":
            depth += 1

        elif ch == "}":
            depth -= 1

            if depth == 0:
                return start, i + 1

        i += 1

    raise RuntimeError(
        "CLASS_UNBALANCED=" + class_name
    )


def replace_class(
    text: str,
    class_name: str,
    replacement: str,
) -> str:

    start, end = class_span(
        text,
        class_name,
    )

    return (
        text[:start]
        + replacement.strip()
        + "\n\n"
        + text[end:].lstrip()
    )


instance = read_json(instance_path)

identity = instance.get(
    "identity",
    {},
)

web = instance.get(
    "web",
    {},
)

android = instance.get(
    "android",
    {},
)

instance_block = instance.get(
    "instance",
    {},
)

community = instance_block.get(
    "community",
    {},
)

native = instance_block.get(
    "native_language",
    {},
)

platform_name = str(
    identity.get(
        "platform_name",
        "SGODA-PUINAVE",
    )
)

platform_status = str(
    identity.get(
        "platform_name_status",
        "PROVISIONAL_PENDING_COMMUNITY_CONFIRMATION",
    )
)

subtitle = str(
    identity.get(
        "institutional_subtitle",
        "",
    )
)

slogan = str(
    identity.get(
        "slogan",
        "",
    )
)

community_name = str(
    community.get(
        "name",
        "",
    )
)

native_name = str(
    native.get(
        "name",
        "Puinave",
    )
)

web_site_name = str(
    web.get(
        "site_name",
        platform_name,
    )
)

web_page_title = str(
    web.get(
        "page_title",
        platform_name,
    )
)

web_short_name = str(
    web.get(
        "short_name",
        platform_name,
    )
)

android_app_name = str(
    android.get(
        "app_name",
        platform_name,
    )
)

source = main_path.read_text(
    encoding="utf-8-sig",
)

required_classes = (
    "DictionarySection",
    "CategoriesSection",
    "LibrarySection",
    "AboutSection",
    "Demo25CategoryDetailPanel",
)

for class_name in required_classes:
    class_span(
        source,
        class_name,
    )

audio_import = (
    "import 'audio_bridge.dart';"
)

for import_line in (
    "import 'demo25_ui_closure_support.g.dart';",
    "import 'external_link.dart';",
):

    if import_line not in source:

        if audio_import not in source:
            raise RuntimeError(
                "AUDIO_IMPORT_ANCHOR_MISSING"
            )

        source = source.replace(
            audio_import,
            audio_import
            + "\n"
            + import_line,
            1,
        )


category_detail = r'''
class Demo25CategoryDetailPanel extends StatelessWidget {
  const Demo25CategoryDetailPanel({
    super.key,
    required this.record,
  });

  final PilotRecord record;

  @override
  Widget build(BuildContext context) {
    final category =
        demo25SemanticCategories[record.lexicalId];

    final semantic =
        (category?['semantic'] ?? '').trim();

    final semanticStatus =
        (category?['semanticStatus'] ?? '').trim();

    final grammatical =
        (category?['grammatical'] ?? '').trim();

    final grammaticalStatus =
        (category?['grammaticalStatus'] ?? '').trim();

    return SizedBox(
      width: 420,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.category_outlined),
                  SizedBox(width: 12),
                  Text(
                    'Categorías',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Semántica / educativa',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                demo25CategoryLabel(semantic),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                demo25PublicStatus(
                  semanticStatus,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Categoría gramatical',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                grammatical.isEmpty
                    ? 'Pendiente de validación'
                    : grammatical,
              ),
              const SizedBox(height: 4),
              Text(
                demo25PublicStatus(
                  grammaticalStatus,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Las clasificaciones semánticas '
                'preliminares se mantienen '
                'diferenciadas de la validación '
                'lingüística y comunitaria.',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''

source = replace_class(
    source,
    "Demo25CategoryDetailPanel",
    category_detail,
)


dictionary = r'''
class DictionarySection extends StatefulWidget {
  const DictionarySection({
    super.key,
    required this.data,
    required this.query,
    required this.searchController,
    required this.playingId,
    required this.onSearch,
    required this.onPlay,
    required this.onStop,
    required this.onOpen,
  });

  final PilotPayload data;
  final String query;
  final TextEditingController searchController;
  final String? playingId;
  final ValueChanged<String> onSearch;
  final Future<void> Function(PilotRecord) onPlay;
  final Future<void> Function() onStop;
  final ValueChanged<PilotRecord> onOpen;

  @override
  State<DictionarySection> createState() =>
      _DictionarySectionState();
}

class _DictionarySectionState
    extends State<DictionarySection> {
  String selectedCategory = '';

  String categoryFor(
    PilotRecord record,
  ) {
    return (
      demo25SemanticCategories[
                record.lexicalId
              ]?['semantic'] ??
          ''
    ).trim();
  }

  List<Map<String, Object>> get configuredCategories {
    return demo25SemanticCategoryCatalog
        .where(
          (item) =>
              item['enabled'] == true,
        )
        .toList()
      ..sort(
        (a, b) {
          final orderA =
              a['order'] as int? ?? 999999;

          final orderB =
              b['order'] as int? ?? 999999;

          if (orderA != orderB) {
            return orderA.compareTo(orderB);
          }

          return (
            a['label'] as String? ?? ''
          ).compareTo(
            b['label'] as String? ?? '',
          );
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final normalized =
        widget.query.trim().toLowerCase();

    final records =
        widget.data.records.where(
      (record) {
        final matchesText =
            normalized.isEmpty ||
            record.puinave
                .toLowerCase()
                .contains(normalized) ||
            record.spanish
                .toLowerCase()
                .contains(normalized) ||
            record.pronunciation
                .toLowerCase()
                .contains(normalized) ||
            record.lexicalId
                .toLowerCase()
                .contains(normalized);

        final category =
            categoryFor(record);

        final matchesCategory =
            selectedCategory.isEmpty ||
            category == selectedCategory;

        return matchesText &&
            matchesCategory;
      },
    ).toList();

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final cardWidth =
            constraints.maxWidth >= 1250
                ? (
                    constraints.maxWidth -
                    96
                  ) /
                  3
                : constraints.maxWidth >= 760
                    ? (
                        constraints.maxWidth -
                        72
                      ) /
                      2
                    : constraints.maxWidth -
                        48;

        return ListView(
          padding:
              const EdgeInsets.all(24),
          children: [
            SectionTitle(
              title:
                  'Diccionario $demo25NativeLanguageName',
              subtitle:
                  'Busque una palabra o filtre '
                  'las fichas por categoría '
                  'semántica.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment:
                  WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width:
                      constraints.maxWidth >=
                              760
                          ? 420
                          : double.infinity,
                  child: TextField(
                    controller:
                        widget.searchController,
                    onChanged:
                        widget.onSearch,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Buscar palabra...',
                      prefixIcon:
                          const Icon(
                        Icons.search,
                      ),
                      suffixIcon:
                          widget.query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip:
                                      'Limpiar',
                                  onPressed:
                                      () {
                                    widget
                                        .searchController
                                        .clear();

                                    widget
                                        .onSearch('');
                                  },
                                  icon:
                                      const Icon(
                                    Icons.close,
                                  ),
                                ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width:
                      constraints.maxWidth >=
                              760
                          ? 300
                          : double.infinity,
                  child:
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        selectedCategory,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Categoría semántica',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text(
                          'Todas las categorías',
                        ),
                      ),
                      ...configuredCategories.map(
                        (item) {
                          final id =
                              item['id']
                                      as String? ??
                                  '';

                          final label =
                              item['label']
                                      as String? ??
                                  id;

                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              label,
                            ),
                          );
                        },
                      ),
                    ],
                    onChanged: (value) {
                      setState(
                        () =>
                            selectedCategory =
                                value ?? '',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${records.length} fichas visibles',
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding:
                      EdgeInsets.all(28),
                  child: Text(
                    'No hay fichas que '
                    'coincidan con los '
                    'filtros seleccionados.',
                  ),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children:
                    records.map(
                  (record) {
                    final playing =
                        widget.playingId ==
                            record.lexicalId;

                    final semantic =
                        categoryFor(record);

                    return SizedBox(
                      width: cardWidth,
                      child: Card(
                        clipBehavior:
                            Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              widget.onOpen(
                            record,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(20),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  record.puinave,
                                  style: Theme.of(
                                    context,
                                  )
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                ),
                                const SizedBox(
                                  height: 6,
                                ),
                                Text(
                                  record
                                      .pronunciation,
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  record.spanish,
                                ),
                                if (semantic
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Chip(
                                    label: Text(
                                      demo25CategoryLabel(
                                        semantic,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  record.lexicalId,
                                  style: Theme.of(
                                    context,
                                  )
                                      .textTheme
                                      .bodySmall,
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
                                Row(
                                  children: [
                                    FilledButton
                                        .tonalIcon(
                                      onPressed:
                                          record
                                                  .audioAvailable
                                              ? () {
                                                  if (playing) {
                                                    widget
                                                        .onStop();
                                                  } else {
                                                    widget
                                                        .onPlay(
                                                      record,
                                                    );
                                                  }
                                                }
                                              : null,
                                      icon: Icon(
                                        playing
                                            ? Icons.stop
                                            : Icons
                                                .volume_up_outlined,
                                      ),
                                      label: Text(
                                        playing
                                            ? 'Detener'
                                            : 'Escuchar',
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons
                                          .arrow_forward,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
          ],
        );
      },
    );
  }
}
'''

# DEMO25_DICTIONARY_STATE_IDEMPOTENCY_V2
#
# DictionarySection and _DictionarySectionState are sibling classes
# in main.dart. replace_class("DictionarySection") does not remove
# the old State class. Remove that old State class first; the
# dictionary template then installs exactly one fresh State class.
#
dictionary_state_pattern = re.compile(
    r"(?m)^[ \t]*class[ \t]+"
    r"_DictionarySectionState\b"
)

dictionary_state_matches = list(
    dictionary_state_pattern.finditer(source)
)

if len(dictionary_state_matches) != 1:
    raise RuntimeError(
        "PRE_REPLACE_DICTIONARY_STATE_COUNT="
        + str(len(dictionary_state_matches))
    )

state_start = dictionary_state_matches[0].start()

state_class_start, state_class_end = class_span(
    source,
    "_DictionarySectionState",
)

if state_class_start != state_start:
    raise RuntimeError(
        "DICTIONARY_STATE_SPAN_MISMATCH"
    )

# Consume only whitespace after the old class.
state_remove_end = state_class_end

while (
    state_remove_end < len(source)
    and source[state_remove_end] in " \t\r\n"
):
    state_remove_end += 1

source = (
    source[:state_class_start]
    + source[state_remove_end:]
)

if list(dictionary_state_pattern.finditer(source)):
    raise RuntimeError(
        "OLD_DICTIONARY_STATE_NOT_REMOVED"
    )

print(
    "OLD_DICTIONARY_STATE_REMOVAL=PASS"
)

source = replace_class(
    source,
    "DictionarySection",
    dictionary,
)

post_dictionary_state_count = len(
    list(
        dictionary_state_pattern.finditer(source)
    )
)

if post_dictionary_state_count != 1:
    raise RuntimeError(
        "POST_REPLACE_DICTIONARY_STATE_COUNT="
        + str(post_dictionary_state_count)
    )

print(
    "DICTIONARY_GENERATOR_IDEMPOTENCY=PASS"
)


categories = r'''
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.data,
    required this.onOpen,
  });

  final PilotPayload data;
  final ValueChanged<PilotRecord> onOpen;

  String categoryFor(
    PilotRecord record,
  ) {
    return (
      demo25SemanticCategories[
                record.lexicalId
              ]?['semantic'] ??
          ''
    ).trim();
  }

  @override
  Widget build(BuildContext context) {
    final grouped =
        <String, List<PilotRecord>>{};

    for (final record in data.records) {
      final semantic =
          categoryFor(record);

      if (
        semantic.isEmpty ||
        !demo25SemanticCategoryEnabled(
          semantic,
        )
      ) {
        continue;
      }

      grouped.putIfAbsent(
        semantic,
        () => <PilotRecord>[],
      );

      grouped[semantic]!.add(
        record,
      );
    }

    final catalog =
        demo25SemanticCategoryCatalog
            .where(
              (item) =>
                  item['enabled'] == true,
            )
            .toList()
          ..sort(
            (a, b) {
              final orderA =
                  a['order'] as int? ??
                      999999;

              final orderB =
                  b['order'] as int? ??
                      999999;

              if (orderA != orderB) {
                return orderA.compareTo(
                  orderB,
                );
              }

              return (
                a['label']
                        as String? ??
                    ''
              ).compareTo(
                b['label']
                        as String? ??
                    '',
              );
            },
          );

    return ListView(
      padding:
          const EdgeInsets.all(24),
      children: [
        const SectionTitle(
          title: 'Categorías',
          subtitle:
              'Explore las fichas agrupadas '
              'por categoría semántica y '
              'educativa. Las clasificaciones '
              'actuales son preliminares y '
              'permanecen pendientes de '
              'validación lingüística.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              catalog.map(
            (item) {
              final code =
                  item['id']
                          as String? ??
                      '';

              final label =
                  item['label']
                          as String? ??
                      code;

              final records =
                  grouped[code] ??
                      <PilotRecord>[];

              return SizedBox(
                width: 420,
                child: Card(
                  clipBehavior:
                      Clip.antiAlias,
                  child: ExpansionTile(
                    leading:
                        const CircleAvatar(
                      child: Icon(
                        Icons
                            .category_outlined,
                      ),
                    ),
                    title: Text(
                      label,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${records.length} '
                      '${records.length == 1 ? "palabra" : "palabras"}\n'
                      'Clasificación preliminar '
                      'pendiente de validación',
                    ),
                    children: records.isEmpty
                        ? const [
                            ListTile(
                              title: Text(
                                'Sin palabras '
                                'asignadas en '
                                'REAL-25.',
                              ),
                            ),
                          ]
                        : records.map(
                            (record) {
                              return ListTile(
                                title: Text(
                                  record
                                      .puinave,
                                ),
                                subtitle: Text(
                                  '${record.spanish}\n'
                                  '${record.lexicalId}',
                                ),
                                isThreeLine:
                                    true,
                                trailing:
                                    const Icon(
                                  Icons
                                      .arrow_forward,
                                ),
                                onTap: () =>
                                    onOpen(
                                  record,
                                ),
                              );
                            },
                          ).toList(),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}
'''

source = replace_class(
    source,
    "CategoriesSection",
    categories,
)


library = r'''
class LibrarySection extends StatelessWidget {
  const LibrarySection({
    super.key,
  });

  Map<String, String>? resourceForType(
    String type,
  ) {
    final matches =
        demo25LibraryResources
            .where(
              (item) =>
                  item['type'] == type,
            )
            .toList();

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  String statusForType(
    String type,
  ) {
    if (
      type == 'NATIVE_CONVERSATION'
    ) {
      return demo25ConversationCount > 0
          ? 'AVAILABLE'
          : 'READY_FOR_AUTHORIZED_CONTENT';
    }

    final resource =
        resourceForType(type);

    return resource?['status'] ??
        'CONFIGURED';
  }

  IconData iconFor(
    String type,
  ) {
    switch (type) {
      case 'BIBLE':
        return Icons.menu_book_outlined;

      case 'DICTIONARY':
        return Icons.library_books_outlined;

      case 'EDUCATIONAL_MATERIAL':
        return Icons.school_outlined;

      case 'PHOTOGRAPHIC_ARCHIVE':
        return Icons.photo_library_outlined;

      case 'DOCUMENTARY_INTERVIEW':
        return Icons.video_library_outlined;

      case 'NATIVE_CONVERSATION':
        return Icons.forum_outlined;

      case 'AUDIO_ARCHIVE':
        return Icons.audiotrack_outlined;

      case 'VIDEO_ARCHIVE':
        return Icons.video_collection_outlined;

      case 'CULTURAL_RESOURCE':
        return Icons.museum_outlined;

      default:
        return Icons.folder_outlined;
    }
  }

  String titleFor(
    Map<String, String> typeEntry,
    String type,
  ) {
    for (final key in [
      'label_es',
      'label',
      'title',
      'name',
    ]) {
      final value =
          (typeEntry[key] ?? '').trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return demo25CategoryLabel(type);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.all(24),
      children: [
        const SectionTitle(
          title: 'Biblioteca Digital',
          subtitle:
              'Recursos culturales, '
              'documentales y educativos '
              'configurados para esta '
              'instancia.',
        ),
        const SizedBox(height: 20),
        ...demo25LibraryResourceTypes.map(
          (typeEntry) {
            final type =
                (
                  typeEntry['type'] ??
                  typeEntry['id'] ??
                  ''
                ).trim();

            final resource =
                resourceForType(type);

            final status =
                statusForType(type);

            final configuredUrl =
                (
                  resource?['url'] ??
                  ''
                ).trim();

            final url =
                type == 'BIBLE' &&
                        configuredUrl
                            .isEmpty
                    ? demo25VerifiedBibleUrl
                    : configuredUrl;

            final canOpen =
                url.startsWith(
                  'https://',
                ) ||
                url.startsWith(
                  'http://',
                );

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 14,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final narrow =
                        constraints.maxWidth <
                            620;

                    final info =
                        Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            titleFor(
                              typeEntry,
                              type,
                            ),
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            demo25PublicStatus(
                              status,
                            ),
                          ),
                          if (
                            type ==
                            'NATIVE_CONVERSATION'
                          ) ...[
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              'Conversaciones '
                              'reales cargadas: '
                              '$demo25ConversationCount',
                            ),
                          ],
                          if (!canOpen) ...[
                            const SizedBox(
                              height: 8,
                            ),
                            const Text(
                              'Sin enlace '
                              'público disponible '
                              'actualmente.',
                            ),
                          ],
                        ],
                      ),
                    );

                    final icon =
                        CircleAvatar(
                      child: Icon(
                        iconFor(type),
                      ),
                    );

                    final button =
                        canOpen
                            ? FilledButton
                                .tonalIcon(
                                onPressed:
                                    () async {
                                  final opened =
                                      await openExternalUrl(
                                    url,
                                  );

                                  if (
                                    !opened &&
                                    context.mounted
                                  ) {
                                    ScaffoldMessenger
                                        .of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text(
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
                                icon:
                                    const Icon(
                                  Icons
                                      .open_in_new,
                                ),
                                label:
                                    const Text(
                                  'Abrir',
                                ),
                              )
                            : null;

                    if (narrow) {
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              icon,
                              const SizedBox(
                                width: 16,
                              ),
                              info,
                            ],
                          ),
                          if (
                            button != null
                          ) ...[
                            const SizedBox(
                              height: 14,
                            ),
                            Align(
                              alignment:
                                  Alignment
                                      .centerLeft,
                              child:
                                  button,
                            ),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        icon,
                        const SizedBox(
                          width: 16,
                        ),
                        info,
                        if (
                          button != null
                        ) ...[
                          const SizedBox(
                            width: 16,
                          ),
                          button,
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Tipos de recursos '
          'configurados: '
          '${demo25LibraryResourceTypes.length}',
        ),
      ],
    );
  }
}
'''

source = replace_class(
    source,
    "LibrarySection",
    library,
)


about = r'''
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.all(32),
      children: [
        SectionTitle(
          title:
              'Acerca de $demo25PlatformName',
          subtitle:
              'Sistema digital para la '
              'preservación, organización '
              'y enseñanza de la lengua '
              '$demo25NativeLanguageName.',
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons
                      .account_tree_outlined,
                  size: 30,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Arquitectura',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Datos lingüísticos, '
                  'servicios API, '
                  'automatización, '
                  'multimedia y cliente '
                  'multiplataforma.',
                ),
                const SizedBox(height: 20),
                Text(
                  'Nombre público: '
                  '$demo25PlatformName',
                ),
                Text(
                  'Estado del nombre: '
                  '${demo25PublicStatus(demo25PlatformNameStatus)}',
                ),
                Text(
                  'Comunidad: '
                  '$demo25CommunityName',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          demo25Slogan,
          style: const TextStyle(
            fontStyle:
                FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
'''

source = replace_class(
    source,
    "AboutSection",
    about,
)


old_category_switch = (
    "SgodaSection.categorias => "
    "CategoriesSection(data: data)"
)

new_category_switch = (
    "SgodaSection.categorias => "
    "CategoriesSection("
    "data: data, "
    "onOpen: (record) => "
    "openRecord(data, record)"
    ")"
)

if old_category_switch in source:
    source = source.replace(
        old_category_switch,
        new_category_switch,
        1,
    )

elif (
    "SgodaSection.categorias => "
    "CategoriesSection("
    not in source
):
    raise RuntimeError(
        "CATEGORY_SWITCH_BINDING_NOT_RESOLVED"
    )


source = source.replace(
    "title: 'SGODA-PUINAVE',",
    "title: demo25WebPageTitle,",
)

source = source.replace(
    "const Text('SGODA-PUINAVE'",
    "Text(demo25PlatformName",
)

source = source.replace(
    "const Text("
    "'Preservación y aprendizaje de la lengua Puinave'",
    "Text(demo25InstitutionalSubtitle",
)


required_after = (
    "Todas las categorías",
    "demo25SemanticCategoryCatalog",
    "demo25SemanticCategoryEnabled",
    "required this.onOpen",
    "openExternalUrl",
    "demo25PlatformName",
    "demo25PublicStatus",
    "demo25CategoryLabel",
)

for marker in required_after:
    if marker not in source:
        raise RuntimeError(
            "POST_TRANSFORM_MARKER_MISSING="
            + marker
        )



# DEMO25_PERSISTENT_EXTERNAL_RESOURCES_BINDING_V1
#
# Persistent config binding:
# external-resources.json -> generated Dart support.
#
external_resources_path = (
    repo
    / "config"
    / "demo25"
    / "instances"
    / "puinave"
    / "external-resources.json"
)

if not external_resources_path.is_file():
    raise RuntimeError(
        "EXTERNAL_RESOURCES_CONFIG_NOT_FOUND="
        + str(external_resources_path)
    )

external_resources_config = read_json(
    external_resources_path
)

def _walk_resources(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_resources(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_resources(child)

bible_candidates = []

for item in _walk_resources(external_resources_config):
    resource_type = str(
        item.get("type", "")
    ).strip().upper()

    resource_id = str(
        item.get("id", "")
    ).strip().lower()

    title = str(
        item.get("title", "")
    ).strip().lower()

    if (
        resource_type == "BIBLE"
        or resource_id == "puinave-bible"
        or "biblia" in title
    ):
        bible_candidates.append(item)

if len(bible_candidates) != 1:
    raise RuntimeError(
        "EXPECTED_EXACTLY_ONE_BIBLE_RESOURCE_FOUND="
        + str(len(bible_candidates))
    )

bible_resource = bible_candidates[0]

bible_status = str(
    bible_resource.get("status", "")
).strip().upper()

bible_visible = bool(
    bible_resource.get("visible_link", False)
)

bible_url = str(
    bible_resource.get("url") or ""
).strip()

if bible_status != "VERIFIED":
    bible_url = ""

if not bible_visible:
    bible_url = ""

if bible_url and not (
    bible_url.startswith("https://")
    or bible_url.startswith("http://")
):
    raise RuntimeError(
        "BIBLE_PUBLIC_URL_SCHEME_INVALID"
    )

def _dart_escape(value):
    return (
        value
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\r", "")
        .replace("\n", "\\n")
    )

support_path = (
    repo
    / "apps"
    / "sgoda_puinave_demo"
    / "lib"
    / "demo25_ui_closure_support.g.dart"
)

if not support_path.is_file():
    raise RuntimeError(
        "GENERATED_SUPPORT_NOT_FOUND="
        + str(support_path)
    )

support_source = support_path.read_text(
    encoding="utf-8"
)

bible_constant_pattern = re.compile(
    r"const\s+String\s+demo25VerifiedBibleUrl\s*=\s*"
    r"(?:r)?['\"][^'\"]*['\"]\s*;"
)

replacement = (
    "const String demo25VerifiedBibleUrl = '"
    + _dart_escape(bible_url)
    + "';"
)

support_source, bible_replace_count = (
    bible_constant_pattern.subn(
        replacement,
        support_source,
        count=1,
    )
)

if bible_replace_count != 1:
    raise RuntimeError(
        "BIBLE_DART_CONSTANT_REPLACE_COUNT="
        + str(bible_replace_count)
    )

support_path.write_text(
    support_source,
    encoding="utf-8",
)

print(
    "EXTERNAL_RESOURCES_CONFIG_BINDING=PASS"
)

print(
    "BIBLE_GENERATED_URL_BINDING="
    + (
        "PASS"
        if bible_url
        else "EMPTY_BY_POLICY"
    )
)

# DEMO25_RUNTIME_EXTERNAL_RESOURCE_RECONCILIATION_BEGIN
# Runtime reconciliation intentionally performed against
# demo25_runtime_config.g.dart after canonical generation.
# main.dart source is not the owner of demo25LibraryResources.
# DEMO25_RUNTIME_EXTERNAL_RESOURCE_RECONCILIATION_END

main_path.write_text(
    source,
    encoding="utf-8",
)


web_index = web_index_path.read_text(
    encoding="utf-8-sig",
)

if re.search(
    r"<title>.*?</title>",
    web_index,
    flags=re.S,
):

    web_index = re.sub(
        r"<title>.*?</title>",
        "<title>"
        + web_page_title
        + "</title>",
        web_index,
        count=1,
        flags=re.S,
    )

else:
    raise RuntimeError(
        "WEB_TITLE_TAG_NOT_FOUND"
    )

web_index_path.write_text(
    web_index,
    encoding="utf-8",
)


web_manifest = read_json(
    web_manifest_path
)

web_manifest["name"] = web_site_name
web_manifest["short_name"] = (
    web_short_name
)

web_manifest_path.write_text(
    json.dumps(
        web_manifest,
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)


android_text = (
    android_manifest_path.read_text(
        encoding="utf-8-sig",
    )
)

if re.search(
    r'android:label="[^"]*"',
    android_text,
):

    android_text = re.sub(
        r'android:label="[^"]*"',
        'android:label="'
        + android_app_name.replace(
            '"',
            "",
        )
        + '"',
        android_text,
        count=1,
    )

else:
    raise RuntimeError(
        "ANDROID_LABEL_NOT_FOUND"
    )

android_manifest_path.write_text(
    android_text,
    encoding="utf-8",
)


print(
    "CATEGORY_CATALOG_TRANSFORM=PASS"
)

print(
    "CATEGORY_GROUPING_TRANSFORM=PASS"
)

print(
    "CATEGORY_FILTER_TRANSFORM=PASS"
)

print(
    "CATEGORY_TO_FLD_TRANSFORM=PASS"
)

print(
    "LIBRARY_TRANSFORM=PASS"
)

print(
    "USER_FRIENDLY_STATUS_TRANSFORM=PASS"
)

print(
    "PUBLIC_IDENTITY_TRANSFORM=PASS"
)

print(
    "WEB_IDENTITY_TRANSFORM=PASS"
)

print(
    "ANDROID_IDENTITY_TRANSFORM=PASS"
)