import 'package:web/web.dart' as web;

String? getItem(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void setItem(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {
    // Storage may be unavailable in privacy-restricted browser contexts.
  }
}

void removeItem(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {
    // Storage may be unavailable in privacy-restricted browser contexts.
  }
}
