import 'dart:convert';

import 'authorization_redirect_policy.dart';

/// The only terminal outcomes the hosted page accepts for a JARM request.
///
/// The browser never signs or rewrites a JARM JWT. It may only deliver a
/// compact JWT returned by Snaplink, or continue to a URL that the HTTP
/// exchange reached through Snaplink's own redirect response.
class JarmCompletion {
  static const blockedMessage =
      'Snaplink did not return a server-signed JARM response or a validated '
      'continuation. No unsigned code or token was redirected.';

  final Uri? redirectTarget;
  final String? formPostHtml;
  final String? error;

  const JarmCompletion._({this.redirectTarget, this.formPostHtml, this.error});

  const JarmCompletion.redirect(Uri target) : this._(redirectTarget: target);

  const JarmCompletion.formPost(String html) : this._(formPostHtml: html);

  const JarmCompletion.blocked([String message = blockedMessage])
    : this._(error: message);

  bool get accepted => redirectTarget != null || formPostHtml != null;
}

JarmCompletion resolveJarmCompletion({
  required String responseMode,
  required String redirectUri,
  required Map<String, dynamic> responseData,
  Uri? serverContinuation,
  String? serverFormPost,
  Uri? authorizationEndpoint,
}) {
  if (!_jarmModes.contains(responseMode)) {
    return const JarmCompletion.blocked('Unsupported JARM response mode.');
  }

  final registeredRedirect = Uri.tryParse(redirectUri);
  if (registeredRedirect == null ||
      redirectUri.isEmpty ||
      !isSafeAuthorizationRedirectUri(registeredRedirect) ||
      registeredRedirect.fragment.isNotEmpty ||
      registeredRedirect.userInfo.isNotEmpty) {
    return const JarmCompletion.blocked();
  }

  if (responseMode == 'form_post.jwt') {
    if (serverFormPost == null ||
        !_isDirectAuthorizationResponse(
          serverContinuation,
          authorizationEndpoint,
        ) ||
        !_isTrustedJarmForm(serverFormPost, registeredRedirect)) {
      return const JarmCompletion.blocked();
    }
    return JarmCompletion.formPost(serverFormPost);
  }

  if (serverContinuation != null &&
      authorizationEndpoint != null &&
      !_sameEndpoint(serverContinuation, authorizationEndpoint) &&
      _isTrustedContinuation(
        responseMode,
        registeredRedirect,
        serverContinuation,
      )) {
    return JarmCompletion.redirect(serverContinuation);
  }

  final response = responseData['response'];
  if (response is! String ||
      !_looksLikeSignedJwt(response) ||
      _containsUnsignedAuthorizationFields(responseData)) {
    return const JarmCompletion.blocked();
  }

  final target = responseMode == 'fragment.jwt'
      ? registeredRedirect.replace(
          fragment: Uri(queryParameters: {'response': response}).query,
        )
      : registeredRedirect.replace(
          queryParameters: {
            ...registeredRedirect.queryParametersAll,
            'response': response,
          },
        );
  return JarmCompletion.redirect(target);
}

/// Validates Snaplink's plain OIDC `form_post` document before the hosted page
/// replaces itself with it. The server has already checked the redirect URI,
/// but an HTML response has no JSON delivery metadata for the browser to
/// inspect, so the form action and response field set are checked locally too.
bool isTrustedAuthorizationFormPost(String html, Uri expectedRedirect) {
  if (!isSafeAuthorizationRedirectUri(expectedRedirect) ||
      expectedRedirect.fragment.isNotEmpty) {
    return false;
  }
  final forms = RegExp(
    r'<form\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).toList(growable: false);
  if (forms.length != 1) return false;
  final formTag = forms.single.group(0)!;
  if (_attribute(formTag, 'method')?.toLowerCase() != 'post') return false;
  final action = _attribute(formTag, 'action');
  final parsedAction = action == null
      ? null
      : Uri.tryParse(_decodeHtmlAttribute(action));
  if (parsedAction == null ||
      !_sameUriWithoutFragment(parsedAction, expectedRedirect)) {
    return false;
  }

  const allowedFields = {'code', 'state', 'iss'};
  final counts = <String, int>{};
  for (final input in RegExp(
    r'<input\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final name = _attribute(input.group(0)!, 'name');
    if (name == null || !allowedFields.contains(name)) return false;
    final count = (counts[name] ?? 0) + 1;
    if (count > 1) return false;
    counts[name] = count;
  }
  return counts['code'] == 1;
}

const _jarmModes = {'jwt', 'query.jwt', 'fragment.jwt', 'form_post.jwt'};

const _unsignedAuthorizationFields = {
  'code',
  'access_token',
  'id_token',
  'token_type',
  'expires_in',
  'scope',
  'state',
  'iss',
  'session_state',
  'error',
  'error_description',
};

bool _containsUnsignedAuthorizationFields(Map<String, dynamic> data) =>
    data.keys.any(_unsignedAuthorizationFields.contains);

bool _isDirectAuthorizationResponse(
  Uri? responseUrl,
  Uri? authorizationEndpoint,
) {
  if (responseUrl == null) return true;
  return authorizationEndpoint != null &&
      _sameUriWithoutFragment(responseUrl, authorizationEndpoint);
}

bool _isTrustedContinuation(String responseMode, Uri expected, Uri actual) {
  if (!_sameEndpoint(expected, actual)) return false;
  if (responseMode == 'fragment.jwt') {
    if (!_sameQuery(expected, actual)) return false;
    final fragment = Uri(query: actual.fragment).queryParametersAll;
    return fragment.length == 1 && _hasOneSignedResponse(fragment['response']);
  }

  if (actual.fragment.isNotEmpty) return false;
  final actualQuery = {
    for (final entry in actual.queryParametersAll.entries)
      if (entry.key != 'response') entry.key: entry.value,
  };
  return _mapOfListsEquals(expected.queryParametersAll, actualQuery) &&
      _hasOneSignedResponse(actual.queryParametersAll['response']);
}

bool _hasOneSignedResponse(List<String>? values) =>
    values != null && values.length == 1 && _looksLikeSignedJwt(values.single);

bool _sameEndpoint(Uri expected, Uri actual) =>
    expected.scheme == actual.scheme &&
    expected.userInfo == actual.userInfo &&
    expected.host == actual.host &&
    expected.port == actual.port &&
    expected.path == actual.path;

bool _sameQuery(Uri expected, Uri actual) =>
    _mapOfListsEquals(expected.queryParametersAll, actual.queryParametersAll);

bool _sameUriWithoutFragment(Uri left, Uri right) =>
    _sameEndpoint(left, right) &&
    _sameQuery(left, right) &&
    left.fragment.isEmpty &&
    right.fragment.isEmpty;

bool _mapOfListsEquals(
  Map<String, List<String>> left,
  Map<String, List<String>> right,
) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null || !_listEquals(entry.value, other)) return false;
  }
  return true;
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _looksLikeSignedJwt(String value) {
  final parts = value.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
  if (parts.any((part) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part))) {
    return false;
  }
  try {
    final header = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    );
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (header is! Map || payload is! Map) return false;
    final algorithm = header['alg']?.toString().trim() ?? '';
    return algorithm.isNotEmpty && algorithm.toLowerCase() != 'none';
  } catch (_) {
    return false;
  }
}

bool _isTrustedJarmForm(String html, Uri expectedRedirect) {
  final forms = RegExp(
    r'<form\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).toList(growable: false);
  if (forms.length != 1) return false;
  final form = forms.single;
  final formTag = form.group(0)!;
  final method = _attribute(formTag, 'method')?.toLowerCase();
  final action = _attribute(formTag, 'action');
  if (method != 'post' || action == null) return false;

  final decodedAction = _decodeHtmlAttribute(action);
  final parsedAction = Uri.tryParse(decodedAction);
  if (parsedAction == null ||
      !_sameUriWithoutFragment(parsedAction, expectedRedirect)) {
    return false;
  }

  String? response;
  for (final input in RegExp(
    r'<input\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final tag = input.group(0)!;
    final name = _attribute(tag, 'name');
    if (_unsignedAuthorizationFields.contains(name)) return false;
    if (name == 'response') {
      if (response != null) return false;
      response = _attribute(tag, 'value');
    }
  }
  return response != null && _looksLikeSignedJwt(response);
}

String? _attribute(String tag, String name) {
  final match = RegExp(
    '''\\b${RegExp.escape(name)}\\s*=\\s*["']([^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(tag);
  return match?.group(1);
}

String _decodeHtmlAttribute(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
