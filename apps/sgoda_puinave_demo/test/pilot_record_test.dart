import 'package:flutter_test/flutter_test.dart';
import 'package:sgoda_puinave_demo/main.dart';

void main() {
  test('REAL-25 record model parses certified API fields', () {
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
}
