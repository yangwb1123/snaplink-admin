import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

/// Access-token persistence for redirect-based auth: a protected route (e.g.
/// /admin/) does a REAL browser redirect to /login/?redirect=[path] when
/// there's no session, and a real redirect back to [path] once login
/// succeeds — both hops are full page loads, so the token can't just live in
/// a Dart field the way it used to. sessionStorage (not localStorage) is
/// intentional: signed-in state shouldn't outlive the browser tab.
///
/// Web only: native builds have no comparable "redirect between paths"
/// concept (there's no page to navigate), so [store]/[read]/[clear] are
/// no-ops off web — callers fall back to the in-memory-only behavior that
/// already existed before this.
class Session {
  static const _tokenKey = 'sso_access_token';

  static void store(String token) {
    if (!kIsWeb) return;
    web.window.sessionStorage.setItem(_tokenKey, token);
  }

  static String? read() {
    if (!kIsWeb) return null;
    return web.window.sessionStorage.getItem(_tokenKey);
  }

  static void clear() {
    if (!kIsWeb) return;
    web.window.sessionStorage.removeItem(_tokenKey);
  }
}
