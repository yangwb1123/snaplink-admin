/// Conservative helpers for keeping credentials out of generic JSON views.
///
/// Domain-specific screens may deliberately reveal a one-time credential in
/// a dedicated, non-persistent view. Generic response, configuration, and
/// approval payload renderers must use this helper instead.
abstract final class SensitiveData {
  static const redacted = '<redacted>';

  static const _sensitiveFragments = {
    'password',
    'passphrase',
    'secret',
    'credential',
    'privatekey',
    'signingkey',
    'encryptionkey',
    'sharedkey',
    'apikey',
    'authorization',
    'recoverycode',
    'otpauth',
    'resourcesjson',
  };

  static bool isSensitiveKey(Object? key) {
    final normalized = key.toString().toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    if (((normalized.endsWith('token') || normalized.endsWith('tokens')) &&
            !const {
              'tokentype',
              'tokenstrategy',
              'tokencount',
            }.contains(normalized)) ||
        normalized == 'clientassertion' ||
        normalized == 'cookie' ||
        normalized == 'setcookie') {
      return true;
    }
    return _sensitiveFragments.any(normalized.contains);
  }

  static bool containsSensitiveField(Object? value) {
    if (value is Map) {
      return value.entries.any(
        (entry) =>
            isSensitiveKey(entry.key) || containsSensitiveField(entry.value),
      );
    }
    if (value is Iterable) return value.any(containsSensitiveField);
    return false;
  }

  static Object? redact(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): isSensitiveKey(entry.key)
              ? redacted
              : redact(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(redact).toList(growable: false);
    }
    return value;
  }
}
