import 'package:flutter/services.dart';

class DemoAudioPlayer {
  static const MethodChannel _channel = MethodChannel('org.sgoda/audio');

  Future<void> play(String url) async {
    await _channel.invokeMethod<void>('play', <String, dynamic>{'url': url});
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  void dispose() {
    _channel.invokeMethod<void>('dispose');
  }
}
