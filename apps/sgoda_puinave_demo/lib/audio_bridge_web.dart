import 'package:web/web.dart' as web;

class DemoAudioPlayer {
  web.HTMLAudioElement? _audio;

  Future<void> play(String url) async {
    stop();

    final audio = web.HTMLAudioElement()
      ..src = url
      ..preload = 'auto';

    _audio = audio;

    audio.play();
  }

  Future<void> stop() async {
    final audio = _audio;

    if (audio != null) {
      audio.pause();
      audio.currentTime = 0;
      _audio = null;
    }
  }

  void dispose() {
    stop();
  }
}
