import 'package:flutter_test/flutter_test.dart';
import 'package:sgoda_puinave_demo/main.dart';

void main() {
  test('REAL-25 legacy record remains parseable', () {
    final record = PilotRecord.fromJson(const <String, dynamic>{
      'lexical_id': 'PU-000001',
      'puinave': 'AMDA',
      'pronunciation': '(´amda)',
      'spanish': 'Huérfana',
      'audio_available': true,
      'audio_url': '/api/demo/pilot25/PU-000001/audio',
    });

    expect(record.lexicalId, 'PU-000001');
    expect(record.puinave, 'AMDA');
    expect(record.spanish, 'Huérfana');
    expect(record.audioAvailable, isTrue);
  });

  test('REAL-508 adapter parses canonical Flutter contract', () {
    final record = Real508RecordAdapter.fromApiResponse(const <String, dynamic>{
      'status': 'ok',
      'data': <String, dynamic>{
        'entryId': '000001',
        'languages': <String, dynamic>{'pu': 'AMDA', 'es': 'Huérfana'},
        'validated': true,
        'media': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'audio',
            'uri': r'C:\REAL508\MP3\PU-000001_pu.mp3',
            'validated': true,
            'autoplay': false,
          },
        ],
        'noInvention': true,
      },
      'no_invention': true,
    });

    expect(record.lexicalId, '000001');
    expect(record.puinave, 'AMDA');
    expect(record.spanish, 'Huérfana');
    expect(record.audioAvailable, isTrue);
    expect(record.audioUrl, r'C:\REAL508\MP3\PU-000001_pu.mp3');
  });

  test('REAL-508 adapter rejects unvalidated audio', () {
    final record = Real508RecordAdapter.fromApiResponse(const <String, dynamic>{
      'status': 'ok',
      'data': <String, dynamic>{
        'entryId': '000508',
        'languages': <String, dynamic>{'pu': 'PRUEBA', 'es': 'Prueba'},
        'media': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'audio',
            'uri': r'C:\REAL508\MP3\PU-000508_pu.mp3',
            'validated': false,
            'autoplay': false,
          },
        ],
        'noInvention': true,
      },
    });

    expect(record.lexicalId, '000508');
    expect(record.audioAvailable, isFalse);
    expect(record.audioUrl, isEmpty);
  });

  test('REAL-508 adapter preserves Puinave text exactly', () {
    final record = Real508RecordAdapter.fromApiResponse(const <String, dynamic>{
      'status': 'ok',
      'data': <String, dynamic>{
        'entryId': '000002',
        'languages': <String, dynamic>{'pu': 'IÃG', 'es': 'Referencia'},
        'media': <dynamic>[],
        'noInvention': true,
      },
    });

    expect(record.puinave, 'IÃG');
  });
}
