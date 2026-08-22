import 'dart:convert';

import 'audio_bridge.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SGODA-PUINAVE',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const Pilot25Page(),
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
    final uri = Uri.parse('$apiBase/api/demo/pilot25');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('SGODA API HTTP ${response.statusCode}');
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return PilotPayload.fromJson(decoded);
  }
}

class Pilot25Page extends StatefulWidget {
  const Pilot25Page({super.key});

  @override
  State<Pilot25Page> createState() => _Pilot25PageState();
}

class _Pilot25PageState extends State<Pilot25Page> {
  final api = PilotApi();
  final player = DemoAudioPlayer();

  late Future<PilotPayload> payload;
  String? playingId;

  @override
  void initState() {
    super.initState();

    payload = api.load();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
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
      setState(() {
        playingId = record.lexicalId;
      });
    }
  }

  Future<void> stop() async {
    await player.stop();

    if (mounted) {
      setState(() {
        playingId = null;
      });
    }
  }

  void reload() {
    setState(() {
      payload = api.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SGODA-PUINAVE'),
        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<PilotPayload>(
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

          return Column(
            children: [
              StatusBanner(
                ready: data.ready,
                records: data.records.length,
                audioComplete: data.audioComplete,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = data.records[index];

                    return WordCard(
                      record: record,
                      isPlaying: playingId == record.lexicalId,
                      onPlay: () => play(record),
                      onStop: stop,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.ready,
    required this.records,
    required this.audioComplete,
  });

  final bool ready;
  final int records;
  final int audioComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(ready ? Icons.check_circle : Icons.warning_amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Piloto REAL-25 · '
                '$records/25 palabras · '
                '$audioComplete/25 audios',
              ),
            ),
          ],
        ),
      ),
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
  });

  final PilotRecord record;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.lexicalId,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.puinave,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (record.pronunciation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(record.pronunciation),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    record.spanish,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: record.audioAvailable
                  ? (isPlaying ? onStop : onPlay)
                  : null,
              icon: Icon(isPlaying ? Icons.stop : Icons.volume_up),
              tooltip: isPlaying ? 'Detener' : 'Escuchar Puinave',
            ),
          ],
        ),
      ),
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
