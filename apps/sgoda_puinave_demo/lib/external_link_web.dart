import 'package:web/web.dart' as web;

Future<bool> openExternalUrl(String url) async {
  final value = url.trim();

  if (!value.startsWith('https://') && !value.startsWith('http://')) {
    return false;
  }

  web.window.open(value, '_blank');
  return true;
}
