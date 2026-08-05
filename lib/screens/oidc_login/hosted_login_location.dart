/// Removes a bearer-equivalent trusted-device credential from an inbound
/// hosted-login URL. Trusted-device grants are sourced exclusively from the
/// client-scoped browser store and are never accepted through navigation.
String hostedLoginLocationWithoutDeviceCredential(Uri current) =>
    _hostedLoginLocationWithout(current, const {'device_token'});

/// Produces a same-product location after a one-time hosted-login action has
/// been submitted. OAuth continuation parameters survive, while verifier and
/// identity material cannot remain in history, copied links, or referrers.
String hostedLoginLocationWithoutOneTimeData(Uri current) =>
    _hostedLoginLocationWithout(current, const {'flow', 'token', 'email'});

String _hostedLoginLocationWithout(Uri current, Set<String> privateKeys) {
  final isLoginPath =
      current.path == '/login' || current.path.startsWith('/login/');
  final query = <String, dynamic>{
    for (final entry in current.queryParametersAll.entries)
      if (!privateKeys.contains(entry.key))
        entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
  };
  return Uri(
    path: isLoginPath ? current.path : '/login/',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
