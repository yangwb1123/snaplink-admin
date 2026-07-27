import 'package:web/web.dart' as web;

String? getItem(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void setItem(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {
    // Storage can be unavailable in privacy-restricted browser contexts.
  }
}

void removeItem(String key) {
  try {
    web.window.localStorage.removeItem(key);
  } catch (_) {
    // Storage can be unavailable in privacy-restricted browser contexts.
  }
}

List<String> keys() {
  try {
    final storage = web.window.localStorage;
    return [
      for (var index = 0; index < storage.length; index++)
        if (storage.key(index) case final String key) key,
    ];
  } catch (_) {
    return const [];
  }
}
