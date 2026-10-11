import 'dart:convert';

import 'package:http/http.dart' as http;

bool isLoopbackServer(String value) {
  final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
  return host == 'localhost' ||
      host == '::1' ||
      host == '[::1]' ||
      host.startsWith('127.');
}

String normalizeServerUrl(String value, {required bool allowLoopback}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError('Escriba una URL HTTP o HTTPS del backend.');
  }
  if (!allowLoopback && isLoopbackServer(value.trim())) {
    throw ArgumentError(
      'Use la IP LAN o URL del servidor, no localhost en el móvil.',
    );
  }
  return uri.toString().replaceFirst(RegExp(r'/+$'), '');
}

class Real508Record {
  const Real508Record({
    required this.lexicalId,
    required this.puinave,
    required this.pronunciation,
    required this.spanish,
    required this.audioAvailable,
    required this.audioUrl,
    this.semanticCategory = '',
    this.semanticCategoryLabel = '',
    this.semanticCategoryStatus = '',
    this.isReal508 = false,
  });

  final String lexicalId;
  final String puinave;
  final String pronunciation;
  final String spanish;
  final bool audioAvailable;
  final String? audioUrl;
  final String semanticCategory;
  final String semanticCategoryLabel;
  final String semanticCategoryStatus;
  final bool isReal508;

  factory Real508Record.fromJson(Map<String, dynamic> json) {
    return Real508Record(
      lexicalId: (json['lexical_id'] ?? '').toString(),
      puinave: (json['puinave'] ?? '').toString(),
      pronunciation: (json['pronunciation'] ?? '').toString(),
      spanish: (json['spanish'] ?? '').toString(),
      audioAvailable: json['audio_available'] == true,
      audioUrl: json['audio_url']?.toString(),
    );
  }
}

class Real508Payload {
  const Real508Payload({
    required this.records,
    required this.ready,
    required this.audioComplete,
    this.categoryCatalog = const <Map<String, Object>>[],
  });

  final List<Real508Record> records;
  final bool ready;
  final int audioComplete;
  final List<Map<String, Object>> categoryCatalog;

  factory Real508Payload.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List<dynamic>? ?? const <dynamic>[];
    final summary =
        json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return Real508Payload(
      records: rawRecords
          .map((item) => Real508Record.fromJson(item as Map<String, dynamic>))
          .toList(),
      ready: summary['ready'] == true,
      audioComplete: (summary['audio_complete'] as num?)?.toInt() ?? 0,
    );
  }
}

class Real508RecordAdapter {
  static Real508Record fromApiResponse(Map<String, dynamic> response) {
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const FormatException('REAL-508: respuesta sin data válida.');
    }

    final entryId = (data['entryId'] ?? '').toString();

    final languagesRaw = data['languages'];
    final languages = languagesRaw is Map<String, dynamic>
        ? languagesRaw
        : const <String, dynamic>{};

    final puinave = (languages['pu'] ?? '').toString();
    final spanish = (languages['es'] ?? '').toString();

    final mediaRaw = data['media'];
    final media = mediaRaw is List<dynamic> ? mediaRaw : const <dynamic>[];

    String audioUrl = '';

    for (final item in media) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final type = (item['type'] ?? '').toString();
      final uri = (item['uri'] ?? '').toString();
      final validated = item['validated'] == true;
      final autoplay = item['autoplay'] == true;

      if (type == 'audio' && validated && !autoplay && uri.isNotEmpty) {
        audioUrl = uri;
        break;
      }
    }

    if (entryId.isEmpty) {
      throw const FormatException('REAL-508: entryId vacío.');
    }

    if (puinave.isEmpty) {
      throw const FormatException('REAL-508: texto Puinave vacío.');
    }

    return Real508Record(
      lexicalId: entryId,
      puinave: puinave,
      pronunciation: (data['pronunciation'] ?? '').toString(),
      spanish: spanish,
      audioAvailable: audioUrl.isNotEmpty,
      audioUrl: audioUrl,
      semanticCategory: (data['category'] ?? '').toString(),
      semanticCategoryLabel: (data['categoryLabel'] ?? '').toString(),
      semanticCategoryStatus: (data['categoryStatus'] ?? '').toString(),
      isReal508: true,
    );
  }
}

// Compatibility names for historical test imports; no pilot data is loaded.
typedef PilotRecord = Real508Record;
typedef PilotPayload = Real508Payload;

class Real508Api {
  Real508Api({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  static const int real508Total = 508;

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('REAL508 HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Stream<Real508Payload> load() async* {
    final status = await _get('/dataset/status');
    if (status['dataset'] != 'REAL508' ||
        status['ready'] != true ||
        status['record_count'] != real508Total) {
      throw StateError('El backend debe contener los 508 registros REAL508.');
    }
    final taxonomy = await _get('/categories/taxonomy');
    final catalog = (taxonomy['semantic_categories'] as List<dynamic>).map((
      value,
    ) {
      final item = value as Map<String, dynamic>;
      return <String, Object>{
        'id': item['id'] as String,
        'label': item['label_es'] as String,
        'enabled': item['enabled'] as bool,
        'order': item['order'] as int,
      };
    }).toList();
    final records = <Real508Record>[];
    for (var start = 1; start <= real508Total; start += 32) {
      final end = (start + 31) > real508Total ? real508Total : start + 31;
      final batch = await Future.wait([
        for (var id = start; id <= end; id++)
          _get('/lexical/${id.toString().padLeft(6, '0')}'),
      ]);
      for (var offset = 0; offset < batch.length; offset++) {
        final record = Real508RecordAdapter.fromApiResponse(batch[offset]);
        final expectedId = (start + offset).toString().padLeft(6, '0');
        if (record.lexicalId != expectedId) {
          throw StateError('ID REAL508 inesperado: ${record.lexicalId}');
        }
        records.add(record);
      }
      yield Real508Payload(
        records: List.unmodifiable(records),
        ready: records.length == real508Total,
        audioComplete: records.where((r) => r.audioAvailable).length,
        categoryCatalog: List.unmodifiable(catalog),
      );
    }
  }

  void dispose() => _client.close();
}

String real508CategoryLabel(String id, List<Map<String, Object>> catalog) {
  for (final item in catalog) {
    if (item['id'] == id) return item['label'] as String;
  }
  return 'Pendiente de categoría';
}
