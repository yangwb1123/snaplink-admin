String clientSecretExpiryLabel(Map<String, dynamic>? client) {
  final raw = client?['client_secret_expires_at'];
  final seconds = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  if (seconds <= 0) return 'Never expires';
  final expiry = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  final remaining = expiry.difference(DateTime.now());
  final date = expiry.toIso8601String().split('T').first;
  if (remaining.isNegative) return 'Expired on $date';
  if (remaining <= const Duration(days: 30)) {
    final days = remaining.inDays < 1 ? '<1' : '${remaining.inDays}';
    return 'Expires in $days day(s) · $date';
  }
  return 'Expires $date';
}

int clientSecretExpiryUnix(Map<String, dynamic>? response) {
  final raw = response?['client_secret_expires_at'];
  return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
}
