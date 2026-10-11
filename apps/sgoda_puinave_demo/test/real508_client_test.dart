import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sgoda_puinave_demo/real508_client.dart';

Map<String, dynamic> status(int count) => {
  'dataset': 'REAL508',
  'ready': count == 508,
  'record_count': count,
};

void main() {
  test(
    'mobile server configuration rejects loopback and preserves LAN URLs',
    () {
      expect(
        () => normalizeServerUrl('http://127.0.0.1:8000', allowLoopback: false),
        throwsArgumentError,
      );
      expect(
        () => normalizeServerUrl('http://localhost:8000', allowLoopback: false),
        throwsArgumentError,
      );
      expect(
        () => normalizeServerUrl('file:///etc/passwd', allowLoopback: false),
        throwsArgumentError,
      );
      expect(
        normalizeServerUrl(' http://192.168.1.20:8000/ ', allowLoopback: false),
        'http://192.168.1.20:8000',
      );
      expect(
        normalizeServerUrl(
          'https://puinave.example/api/',
          allowLoopback: false,
        ),
        'https://puinave.example/api',
      );
    },
  );
  test(
    'rejects a pilot-only backend before requesting any lexical record',
    () async {
      final paths = <String>[];
      final api = Real508Api(
        baseUrl: 'http://server',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode(status(25)), 200);
        }),
      );
      await expectLater(api.load(), emitsError(isA<StateError>()));
      expect(paths, ['/dataset/status']);
      api.dispose();
    },
  );

  test(
    'loads all 508 canonical records and categories from the live contract',
    () async {
      final ids = <String>[];
      final api = Real508Api(
        baseUrl: 'http://server',
        client: MockClient((request) async {
          if (request.url.path == '/dataset/status') {
            return http.Response(jsonEncode(status(508)), 200);
          }
          if (request.url.path == '/categories/taxonomy') {
            return http.Response(
              jsonEncode({
                'semantic_categories': [
                  {
                    'id': 'time',
                    'label_es': 'Tiempo',
                    'enabled': true,
                    'order': 140,
                  },
                ],
              }),
              200,
            );
          }
          final id = request.url.path.split('/').last;
          ids.add(id);
          return http.Response(
            jsonEncode({
              'data': {
                'entryId': id,
                'languages': {'pu': ' Ã ', 'es': ' Traducción '},
                'pronunciation': ' (á) ',
                'category': 'time',
                'categoryLabel': 'Tiempo',
                'categoryStatus': 'USER_APPROVED_EDUCATIONAL',
                'media': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final batches = await api.load().toList();
      final result = batches.last;
      expect(result.ready, true);
      expect(result.records.length, 508);
      expect(ids.toSet().length, 508);
      expect(result.records.first.lexicalId, '000001');
      expect(result.records.last.lexicalId, '000508');
      expect(result.records.first.puinave, ' Ã ');
      expect(result.records.first.pronunciation, ' (á) ');
      expect(result.records.first.semanticCategory, 'time');
      expect(real508CategoryLabel('time', result.categoryCatalog), 'Tiempo');
      expect(batches.take(batches.length - 1).every((b) => !b.ready), true);
      api.dispose();
    },
  );

  test(
    'HTTP failure never produces a ready payload or substitutes pilot records',
    () async {
      final api = Real508Api(
        baseUrl: 'http://server',
        client: MockClient((request) async {
          return http.Response('Unavailable', 503);
        }),
      );
      await expectLater(api.load(), emitsError(isA<StateError>()));
      api.dispose();
    },
  );
}
