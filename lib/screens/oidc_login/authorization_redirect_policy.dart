/// Redirect URI policy shared by plain OAuth and JARM delivery.
///
/// It mirrors Snaplink's DCR validation: HTTPS, loopback HTTP, and registered
/// native schemes are supported; fragments, embedded credentials, relative
/// URLs, and executable/browser-local schemes are rejected.
bool isSafeAuthorizationRedirectUri(Uri uri) {
  if (!uri.isAbsolute ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      const {
        'about',
        'blob',
        'data',
        'file',
        'javascript',
        'vbscript',
      }.contains(uri.scheme.toLowerCase())) {
    return false;
  }
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  if (uri.scheme == 'http') {
    return uri.host == 'localhost' ||
        uri.host == '::1' ||
        uri.host.startsWith('127.');
  }
  return true;
}
