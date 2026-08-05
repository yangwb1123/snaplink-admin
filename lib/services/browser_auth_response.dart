import 'browser_auth_response_stub.dart'
    if (dart.library.js_interop) 'browser_auth_response_web.dart'
    as platform;

/// Browser-only delivery mechanisms used by OAuth response modes.
abstract final class BrowserAuthResponse {
  static bool submitForm(String uri, Map<String, String> fields) =>
      platform.submitForm(uri, fields);

  static bool replaceDocument(String html) => platform.replaceDocument(html);
}
