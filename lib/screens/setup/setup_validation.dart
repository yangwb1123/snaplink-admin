/// Parses the optional first application's redirect URI list.
///
/// OAuth redirect URIs cannot carry fragments, and embedded user-info is
/// rejected to avoid displaying or forwarding credential-like URL material.
List<String> parseSetupRedirectUris(String input) {
  final values = input
      .split(RegExp(r'[\r\n,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  for (final value in values) {
    final uri = Uri.tryParse(value);
    final localhost =
        uri?.scheme == 'http' &&
        (uri?.host == 'localhost' || uri?.host == '127.0.0.1');
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && !localhost)) {
      throw const FormatException(
        'Each redirect URI must be absolute HTTPS (HTTP is allowed only for '
        'localhost) and must not contain user info or a fragment.',
      );
    }
  }
  return values;
}
