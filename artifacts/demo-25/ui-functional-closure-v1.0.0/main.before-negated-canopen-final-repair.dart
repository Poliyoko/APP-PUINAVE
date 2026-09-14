import 'dart:convert';

import 'audio_bridge.dart';
import 'external_link.dart';
import 'demo25_ui_closure_support.g.dart';
import 'demo25_external_resource_links.g.dart';
import 'demo25_runtime_config.g.dart' hide demo25NativeLanguageName;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SgodaPuinaveApp());
}

const apiBase = String.fromEnvironment(
  'SGODA_API_BASE',
  defaultValue: 'http://127.0.0.1:8010',
);

class SgodaPuinaveApp extends StatelessWidget {
  const SgodaPuinaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF356B3D);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: demo25WebPageTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F2),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      home: const SgodaHomePage(),
    );
  }
}

class PilotRecord {
  const PilotRecord({
    required this.lexicalId,
    required this.puinave,
    required this.pronunciation,
    required this.spanish,
    required this.audioAvailable,
    required this.audioUrl,
  });

  final String lexicalId;
  final String puinave;
  final String pronunciation;
  final String spanish;
  final bool audioAvailable;
  final String? audioUrl;

  factory PilotRecord.fromJson(Map<String, dynamic> json) {
    return PilotRecord(
      lexicalId: (json['lexical_id'] ?? '').toString(),
      puinave: (json['puinave'] ?? '').toString(),
      pronunciation: (json['pronunciation'] ?? '').toString(),
      spanish: (json['spanish'] ?? '').toString(),
      audioAvailable: json['audio_available'] == true,
      audioUrl: json['audio_url']?.toString(),
    );
  }
}

class PilotPayload {
  const PilotPayload({
    required this.records,
    required this.ready,
    required this.audioComplete,
  });

  final List<PilotRecord> records;
  final bool ready;
  final int audioComplete;

  factory PilotPayload.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List<dynamic>? ?? const <dynamic>[];
    final summary =
        json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return PilotPayload(
      records: rawRecords
          .map((item) => PilotRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      ready: summary['ready'] == true,
      audioComplete: (summary['audio_complete'] as num?)?.toInt() ?? 0,
    );
  }
}

class PilotApi {
  Future<PilotPayload> load() async {
    final response = await http.get(Uri.parse('$apiBase/api/demo/pilot25'));

    if (response.statusCode != 200) {
      throw Exception('SGODA API HTTP ${response.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return PilotPayload.fromJson(decoded);
  }
}

enum SgodaSection {
  inicio,
  diccionario,
  categorias,
  biblioteca,
  conversaciones,
  acerca,
}

class SgodaHomePage extends StatefulWidget {
  const SgodaHomePage({super.key});

  @override
  State<SgodaHomePage> createState() => _SgodaHomePageState();
}

class _SgodaHomePageState extends State<SgodaHomePage> {
  final api = PilotApi();
  final player = DemoAudioPlayer();
  final searchController = TextEditingController();

  late Future<PilotPayload> payload;
  SgodaSection section = SgodaSection.inicio;
  String query = '';
  String? playingId;

  @override
  void initState() {
    super.initState();
    payload = api.load();
  }

  @override
  void dispose() {
    searchController.dispose();
    player.dispose();
    super.dispose();
  }

  void reload() {
    setState(() {
      payload = api.load();
    });
  }

  Future<void> play(PilotRecord record) async {
    if (!record.audioAvailable || record.audioUrl == null) {
      return;
    }

    final relativeUrl = record.audioUrl!;
    final url = relativeUrl.startsWith('http')
        ? relativeUrl
        : '$apiBase$relativeUrl';

    await player.stop();
    await player.play(url);

    if (mounted) {
      setState(() => playingId = record.lexicalId);
    }
  }

  Future<void> stop() async {
    await player.stop();

    if (mounted) {
      setState(() => playingId = null);
    }
  }

  void openRecord(PilotPayload data, PilotRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LexicalDetailPage(
          records: data.records,
          initialIndex: data.records.indexOf(record),
          player: player,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(child: Icon(Icons.language)),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SGODA-PUINAVE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Preservación y aprendizaje de la lengua Puinave',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: reload,
                tooltip: 'Actualizar datos',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: NavigationPanel(
                      section: section,
                      onSelected: (value) {
                        setState(() => section = value);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (wide)
                SizedBox(
                  width: 250,
                  child: NavigationPanel(
                    section: section,
                    onSelected: (value) => setState(() => section = value),
                  ),
                ),
              Expanded(
                child: FutureBuilder<PilotPayload>(
                  future: payload,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return ErrorView(
                        message: snapshot.error.toString(),
                        onRetry: reload,
                      );
                    }

                    final data = snapshot.data!;

                    return switch (section) {
                      SgodaSection.inicio => HomeSection(
                        data: data,
                        onDictionary: () =>
                            setState(() => section = SgodaSection.diccionario),
                      ),
                      SgodaSection.diccionario => DictionarySection(
                        data: data,
                        query: query,
                        searchController: searchController,
                        playingId: playingId,
                        onSearch: (value) => setState(() => query = value),
                        onPlay: play,
                        onStop: stop,
                        onOpen: (record) => openRecord(data, record),
                      ),
                      SgodaSection.categorias => CategoriesSection(
                        data: data,
                        onOpen: (record) => openRecord(data, record),
                      ),
                      SgodaSection.biblioteca => const LibrarySection(),
                      SgodaSection.conversaciones =>
                        const ConversationsSection(),
                      SgodaSection.acerca => const AboutSection(),
                    };
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.section,
    required this.onSelected,
  });

  final SgodaSection section;
  final ValueChanged<SgodaSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Plataforma educativa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          NavigationTile(
            icon: Icons.home_outlined,
            label: 'Inicio',
            selected: section == SgodaSection.inicio,
            onTap: () => onSelected(SgodaSection.inicio),
          ),
          NavigationTile(
            icon: Icons.menu_book_outlined,
            label: 'Diccionario',
            selected: section == SgodaSection.diccionario,
            onTap: () => onSelected(SgodaSection.diccionario),
          ),
          NavigationTile(
            icon: Icons.category_outlined,
            label: 'Categorías',
            selected: section == SgodaSection.categorias,
            onTap: () => onSelected(SgodaSection.categorias),
          ),
          NavigationTile(
            icon: Icons.local_library_outlined,
            label: 'Biblioteca Digital',
            selected: section == SgodaSection.biblioteca,
            onTap: () => onSelected(SgodaSection.biblioteca),
          ),
          NavigationTile(
            icon: Icons.forum_outlined,
            label: 'Conversaciones nativas',
            selected: section == SgodaSection.conversaciones,
            onTap: () => onSelected(SgodaSection.conversaciones),
          ),
          NavigationTile(
            icon: Icons.info_outline,
            label: 'Acerca de SGODA',
            selected: section == SgodaSection.acerca,
            onTap: () => onSelected(SgodaSection.acerca),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Tecnología para preservar la memoria del pueblo Puinave.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationTile extends StatelessWidget {
  const NavigationTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.data,
    required this.onDictionary,
  });

  final PilotPayload data;
  final VoidCallback onDictionary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Wrap(
            spacing: 28,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'La lengua Puinave vive en cada palabra.',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Explore el diccionario digital, conozca la '
                      'pronunciación y escuche la voz Puinave.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onDictionary,
                icon: const Icon(Icons.menu_book),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Explorar diccionario'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        StatusDashboard(data: data),
        const SizedBox(height: 24),
        const SectionTitle(
          title: 'Aprender y preservar',
          subtitle:
              'Una plataforma digital construida para conservar y '
              'compartir el conocimiento lingüístico Puinave.',
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FeatureCard(
              icon: Icons.record_voice_over,
              title: 'Escuchar',
              text: 'Pronunciaciones vinculadas a cada entrada léxica.',
            ),
            FeatureCard(
              icon: Icons.translate,
              title: 'Comprender',
              text: 'Puinave, pronunciación y traducción en una ficha.',
            ),
            FeatureCard(
              icon: Icons.school_outlined,
              title: 'Aprender',
              text: 'Base para experiencias educativas y multimedia.',
            ),
          ],
        ),
      ],
    );
  }
}

class StatusDashboard extends StatelessWidget {
  const StatusDashboard({super.key, required this.data});

  final PilotPayload data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          icon: Icons.library_books_outlined,
          value: '${data.records.length}',
          label: 'Palabras REAL-25',
        ),
        MetricCard(
          icon: Icons.volume_up_outlined,
          value: '${data.audioComplete}',
          label: 'Audios disponibles',
        ),
        MetricCard(
          icon: data.ready ? Icons.check_circle_outline : Icons.warning_amber,
          value: data.ready ? 'Listo' : 'Revisar',
          label: 'Estado del piloto',
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle),
      ],
    );
  }
}

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
  State<DictionarySection> createState() => _DictionarySectionState();
}

class _DictionarySectionState extends State<DictionarySection> {
  String selectedCategory = '';

  String categoryFor(PilotRecord record) {
    return (demo25SemanticCategories[record.lexicalId]?['semantic'] ?? '')
        .trim();
  }

  List<Map<String, Object>> get configuredCategories {
    return demo25SemanticCategoryCatalog
        .where((item) => item['enabled'] == true)
        .toList()
      ..sort((a, b) {
        final orderA = a['order'] as int? ?? 999999;

        final orderB = b['order'] as int? ?? 999999;

        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }

        return (a['label'] as String? ?? '').compareTo(
          b['label'] as String? ?? '',
        );
      });
  }

  @override
  Widget build(BuildContext context) {
    final normalized = widget.query.trim().toLowerCase();

    final records = widget.data.records.where((record) {
      final matchesText =
          normalized.isEmpty ||
          record.puinave.toLowerCase().contains(normalized) ||
          record.spanish.toLowerCase().contains(normalized) ||
          record.pronunciation.toLowerCase().contains(normalized) ||
          record.lexicalId.toLowerCase().contains(normalized);

      final category = categoryFor(record);

      final matchesCategory =
          selectedCategory.isEmpty || category == selectedCategory;

      return matchesText && matchesCategory;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1250
            ? (constraints.maxWidth - 96) / 3
            : constraints.maxWidth >= 760
            ? (constraints.maxWidth - 72) / 2
            : constraints.maxWidth - 48;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionTitle(
              title: 'Diccionario $demo25NativeLanguageName',
              subtitle:
                  'Busque una palabra o filtre '
                  'las fichas por categoría '
                  'semántica.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 760 ? 420 : double.infinity,
                  child: TextField(
                    controller: widget.searchController,
                    onChanged: widget.onSearch,
                    decoration: InputDecoration(
                      hintText: 'Buscar palabra...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: widget.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar',
                              onPressed: () {
                                widget.searchController.clear();

                                widget.onSearch('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 760 ? 300 : double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría semántica',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todas las categorías'),
                      ),
                      ...configuredCategories.map((item) {
                        final id = item['id'] as String? ?? '';

                        final label = item['label'] as String? ?? id;

                        return DropdownMenuItem(value: id, child: Text(label));
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => selectedCategory = value ?? '');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${records.length} fichas visibles'),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
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
                children: records.map((record) {
                  final playing = widget.playingId == record.lexicalId;

                  final semantic = categoryFor(record);

                  return SizedBox(
                    width: cardWidth,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onOpen(record),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.puinave,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(record.pronunciation),
                              const SizedBox(height: 8),
                              Text(record.spanish),
                              if (semantic.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Chip(
                                  label: Text(demo25CategoryLabel(semantic)),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                record.lexicalId,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: record.audioAvailable
                                        ? () {
                                            if (playing) {
                                              widget.onStop();
                                            } else {
                                              widget.onPlay(record);
                                            }
                                          }
                                        : null,
                                    icon: Icon(
                                      playing
                                          ? Icons.stop
                                          : Icons.volume_up_outlined,
                                    ),
                                    label: Text(
                                      playing ? 'Detener' : 'Escuchar',
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}

class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.record,
    required this.isPlaying,
    required this.onPlay,
    required this.onStop,
    required this.onOpen,
  });

  final PilotRecord record;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.lexicalId,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: record.audioAvailable
                        ? (isPlaying ? onStop : onPlay)
                        : null,
                    icon: Icon(isPlaying ? Icons.stop : Icons.volume_up),
                    tooltip: isPlaying ? 'Detener' : 'Escuchar Puinave',
                  ),
                ],
              ),
              const Spacer(),
              Text(
                record.puinave,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (record.pronunciation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(record.pronunciation),
              ],
              const SizedBox(height: 10),
              Text(
                record.spanish,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.open_in_new, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Abrir ficha léxica',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LexicalDetailPage extends StatefulWidget {
  const LexicalDetailPage({
    super.key,
    required this.records,
    required this.initialIndex,
    required this.player,
  });

  final List<PilotRecord> records;
  final int initialIndex;
  final DemoAudioPlayer player;

  @override
  State<LexicalDetailPage> createState() => _LexicalDetailPageState();
}

class _LexicalDetailPageState extends State<LexicalDetailPage> {
  late int index;
  bool playing = false;

  PilotRecord get record => widget.records[index];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  Future<void> toggleAudio() async {
    if (!record.audioAvailable || record.audioUrl == null) return;

    if (playing) {
      await widget.player.stop();

      if (mounted) {
        setState(() => playing = false);
      }

      return;
    }

    final relative = record.audioUrl!;
    final url = relative.startsWith('http') ? relative : '$apiBase$relative';

    await widget.player.stop();
    await widget.player.play(url);

    if (mounted) {
      setState(() => playing = true);
    }
  }

  Future<void> move(int delta) async {
    await widget.player.stop();

    final next = index + delta;

    if (next < 0 || next >= widget.records.length) return;

    setState(() {
      index = next;
      playing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha Léxica Digital')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                record.lexicalId,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Text(
                record.puinave,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (record.pronunciation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.pronunciation,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DetailPanel(
                    icon: Icons.translate,
                    title: 'Español',
                    value: record.spanish,
                  ),
                  const DetailPanel(
                    icon: Icons.image_outlined,
                    title: 'Imagen',
                    value: 'Recurso multimedia pendiente de vinculación.',
                  ),
                  Demo25MultilingualFldPanel(record: record),
                  Demo25CategoryDetailPanel(record: record),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over, size: 36),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pronunciación Puinave',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Audio nativo asociado a esta entrada.'),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: record.audioAvailable ? toggleAudio : null,
                        icon: Icon(playing ? Icons.stop : Icons.volume_up),
                        label: Text(playing ? 'Detener' : 'Escuchar'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: index > 0 ? () => move(-1) : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  ),
                  const Spacer(),
                  Text('${index + 1} / ${widget.records.length}'),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: index < widget.records.length - 1
                        ? () => move(1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailPanel extends StatelessWidget {
  const DetailPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(value),
            ],
          ),
        ),
      ),
    );
  }
}

// DEMO25_MULTILINGUAL_LIBRARY_BINDING_V1

class Demo25MultilingualFldPanel extends StatefulWidget {
  const Demo25MultilingualFldPanel({super.key, required this.record});

  final PilotRecord record;

  @override
  State<Demo25MultilingualFldPanel> createState() =>
      _Demo25MultilingualFldPanelState();
}

class _Demo25MultilingualFldPanelState
    extends State<Demo25MultilingualFldPanel> {
  String languageCode = 'es';
  bool reverseDirection = false;

  Map<String, String> get selectedLanguage {
    return demo25AuxLanguages.firstWhere(
      (item) => item['code'] == languageCode,
      orElse: () => demo25AuxLanguages.first,
    );
  }

  bool get contentAvailable {
    return languageCode == 'es' &&
        selectedLanguage['availability'] == 'AVAILABLE_IN_REAL25';
  }

  String get auxiliaryText {
    if (languageCode == 'es') {
      return widget.record.spanish;
    }

    return 'Contenido pendiente de incorporación y validación.';
  }

  @override
  Widget build(BuildContext context) {
    final languageName = selectedLanguage['name'] ?? languageCode;

    final availability = selectedLanguage['availability'] ?? 'PENDING_CONTENT';

    return SizedBox(
      width: 420,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.translate),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FLD multilingüe',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: languageCode,
                decoration: const InputDecoration(
                  labelText: 'Idioma auxiliar',
                  border: OutlineInputBorder(),
                ),
                items: demo25AuxLanguages
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['code'],
                        child: Text(item['name'] ?? item['code']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    languageCode = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: reverseDirection,
                onChanged: (value) {
                  setState(() {
                    reverseDirection = value;
                  });
                },
                title: Text(
                  reverseDirection
                      ? '$languageName → Puinave'
                      : 'Puinave → $languageName',
                ),
                subtitle: const Text('Cambiar dirección de aprendizaje'),
              ),
              const Divider(),
              Text(
                reverseDirection ? languageName : 'Puinave',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                reverseDirection ? auxiliaryText : widget.record.puinave,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text(
                reverseDirection ? 'Puinave' : languageName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(reverseDirection ? widget.record.puinave : auxiliaryText),
              const SizedBox(height: 14),
              Chip(
                avatar: Icon(
                  contentAvailable
                      ? Icons.check_circle_outline
                      : Icons.schedule_outlined,
                ),
                label: Text(
                  contentAvailable
                      ? 'Contenido disponible'
                      : 'Contenido pendiente · $availability',
                ),
              ),
              if (!contentAvailable) ...[
                const SizedBox(height: 8),
                const Text(
                  'SGODA no inventa traducciones. '
                  'El contenido aparecerá cuando sea '
                  'incorporado y validado.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Demo25CategoryDetailPanel extends StatelessWidget {
  const Demo25CategoryDetailPanel({super.key, required this.record});

  final PilotRecord record;

  @override
  Widget build(BuildContext context) {
    final category = demo25SemanticCategories[record.lexicalId];

    final semantic = (category?['semantic'] ?? '').trim();

    final semanticStatus = (category?['semanticStatus'] ?? '').trim();

    final grammatical = (category?['grammatical'] ?? '').trim();

    final grammaticalStatus = (category?['grammaticalStatus'] ?? '').trim();

    return SizedBox(
      width: 420,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.category_outlined),
                  SizedBox(width: 12),
                  Text(
                    'Categorías',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Semántica / educativa',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                demo25CategoryLabel(semantic),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(demo25PublicStatus(semanticStatus)),
              const SizedBox(height: 18),
              Text(
                'Categoría gramatical',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                grammatical.isEmpty ? 'Pendiente de validación' : grammatical,
              ),
              const SizedBox(height: 4),
              Text(demo25PublicStatus(grammaticalStatus)),
              const SizedBox(height: 16),
              const Text(
                'Las clasificaciones semánticas '
                'preliminares se mantienen '
                'diferenciadas de la validación '
                'lingüística y comunitaria.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.data,
    required this.onOpen,
  });

  final PilotPayload data;
  final ValueChanged<PilotRecord> onOpen;

  String categoryFor(PilotRecord record) {
    return (demo25SemanticCategories[record.lexicalId]?['semantic'] ?? '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<PilotRecord>>{};

    for (final record in data.records) {
      final semantic = categoryFor(record);

      if (semantic.isEmpty || !demo25SemanticCategoryEnabled(semantic)) {
        continue;
      }

      grouped.putIfAbsent(semantic, () => <PilotRecord>[]);

      grouped[semantic]!.add(record);
    }

    final catalog =
        demo25SemanticCategoryCatalog
            .where((item) => item['enabled'] == true)
            .toList()
          ..sort((a, b) {
            final orderA = a['order'] as int? ?? 999999;

            final orderB = b['order'] as int? ?? 999999;

            if (orderA != orderB) {
              return orderA.compareTo(orderB);
            }

            return (a['label'] as String? ?? '').compareTo(
              b['label'] as String? ?? '',
            );
          });

    return ListView(
      padding: const EdgeInsets.all(24),
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
          children: catalog.map((item) {
            final code = item['id'] as String? ?? '';

            final label = item['label'] as String? ?? code;

            final records = grouped[code] ?? <PilotRecord>[];

            return SizedBox(
              width: 420,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.category_outlined),
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                      : records.map((record) {
                          return ListTile(
                            title: Text(record.puinave),
                            subtitle: Text(
                              '${record.spanish}\n'
                              '${record.lexicalId}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => onOpen(record),
                          );
                        }).toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key});

  Map<String, String>? resourceForType(String type) {
    final matches = demo25LibraryResources
        .where((item) => item['type'] == type)
        .toList();

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  String statusForType(String type) {
    if (type == 'NATIVE_CONVERSATION') {
      return demo25ConversationCount > 0
          ? 'AVAILABLE'
          : 'READY_FOR_AUTHORIZED_CONTENT';
    }

    final resource = resourceForType(type);

    return resource?['status'] ?? 'CONFIGURED';
  }

  IconData iconFor(String type) {
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

  String titleFor(Map<String, String> typeEntry, String type) {
    for (final key in ['label_es', 'label', 'title', 'name']) {
      final value = (typeEntry[key] ?? '').trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return demo25CategoryLabel(type);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
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
        ...demo25LibraryResourceTypes.map((typeEntry) {
          final type = (typeEntry['type'] ?? typeEntry['id'] ?? '').trim();

          final resource = resourceForType(type);

          final status = statusForType(type);

          final resourceId = (resource?['id'] ?? '').trim();

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

          final useLegacyFallback = publicLinks.isEmpty && legacyCanOpen;

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;

                  final info = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleFor(typeEntry, type),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(demo25PublicStatus(status)),
                        if (type == 'NATIVE_CONVERSATION') ...[
                          const SizedBox(height: 6),
                          Text(
                            'Conversaciones '
                            'reales cargadas: '
                            '$demo25ConversationCount',
                          ),
                        ],
                        if (!canOpen) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Sin enlace '
                            'público disponible '
                            'actualmente.',
                          ),
                        ],
                      ],
                    ),
                  );

                  final icon = CircleAvatar(child: Icon(iconFor(type)));

                  Future<void> openLink(String url) async {
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
                      : Wrap(spacing: 8, runSpacing: 8, children: linkButtons);

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [icon, const SizedBox(width: 16), info],
                        ),
                        if (buttons != null) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: buttons,
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 16),
                      info,
                      if (buttons != null) ...[
                        const SizedBox(width: 16),
                        Flexible(child: buttons),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        }),
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

class ConversationsSection extends StatefulWidget {
  const ConversationsSection({super.key});

  @override
  State<ConversationsSection> createState() => _ConversationsSectionState();
}

class _ConversationsSectionState extends State<ConversationsSection> {
  String languageCode = 'es';
  bool reverseDirection = false;

  @override
  Widget build(BuildContext context) {
    final language = demo25AuxLanguages.firstWhere(
      (item) => item['code'] == languageCode,
      orElse: () => demo25AuxLanguages.first,
    );

    final languageName = language['name'] ?? languageCode;

    final availability = language['availability'] ?? 'PENDING_CONTENT';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionTitle(
          title: 'Conversaciones nativas',
          subtitle:
              'Aprendizaje mediante conversaciones reales '
              'entre hablantes nativos, con idiomas '
              'auxiliares configurables.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selector de idioma',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: languageCode,
                  decoration: const InputDecoration(
                    labelText: 'Idioma auxiliar',
                    border: OutlineInputBorder(),
                  ),
                  items: demo25AuxLanguages
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['code'],
                          child: Text(item['name'] ?? item['code']!),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      languageCode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reverseDirection,
                  onChanged: (value) {
                    setState(() {
                      reverseDirection = value;
                    });
                  },
                  title: Text(
                    reverseDirection
                        ? '$languageName → Puinave'
                        : 'Puinave → $languageName',
                  ),
                  subtitle: const Text(
                    'La dirección se deriva dinámicamente '
                    'sin duplicar la conversación.',
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    languageCode == 'es'
                        ? 'Español disponible en REAL-25'
                        : 'Contenido: $availability',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 48),
                const SizedBox(height: 14),
                Text(
                  demo25ConversationCount == 0
                      ? 'Colección preparada'
                      : '$demo25ConversationCount '
                            'conversaciones disponibles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (demo25ConversationCount == 0)
                  const Text(
                    'No se muestran conversaciones ficticias. '
                    'El módulo está preparado para incorporar '
                    'conversaciones reales verificadas y '
                    'autorizadas.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        SectionTitle(
          title: 'Acerca de $demo25PlatformName',
          subtitle:
              'Sistema digital para la '
              'preservación, organización '
              'y enseñanza de la lengua '
              '$demo25NativeLanguageName.',
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_tree_outlined, size: 30),
                const SizedBox(height: 18),
                const Text(
                  'Arquitectura',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        Text(demo25Slogan, style: const TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 16),
            const Text('No fue posible conectar con SGODA.'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
