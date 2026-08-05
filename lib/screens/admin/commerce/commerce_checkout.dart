typedef CommerceCheckoutOrigin = Uri Function();
typedef CommerceCheckoutNavigator = bool Function(Uri target);

class CommerceCheckoutNavigationUnavailable implements Exception {
  const CommerceCheckoutNavigationUnavailable();
}

class CommerceCheckoutUrls {
  final Uri success;
  final Uri cancel;

  const CommerceCheckoutUrls({required this.success, required this.cancel});

  factory CommerceCheckoutUrls.fromOrigin(Uri origin) {
    if (!_isTrustedConsoleOrigin(origin)) {
      throw StateError('The console origin cannot be used for checkout.');
    }
    final base = Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
    );
    return CommerceCheckoutUrls(
      success: base.replace(
        path: '/admin/commerce',
        queryParameters: const {'checkout': 'complete'},
      ),
      cancel: base.replace(
        path: '/admin/commerce',
        queryParameters: const {'checkout': 'cancelled'},
      ),
    );
  }
}

String commerceCheckoutOrderID(Map<String, dynamic> response) {
  final order = response['order'];
  final id = order is Map ? order['id']?.toString().trim() ?? '' : '';
  if (id.isEmpty) throw const FormatException('Missing payment order ID.');
  return id;
}

Uri commerceCheckoutRedirect(Map<String, dynamic> response) {
  final raw = response['redirect_url']?.toString().trim() ?? '';
  final redirect = Uri.tryParse(raw);
  if (raw.isEmpty ||
      raw.length > 4096 ||
      raw.contains(RegExp(r'[\x00-\x20\\]')) ||
      redirect == null ||
      redirect.scheme != 'https' ||
      redirect.host.isEmpty ||
      redirect.userInfo.isNotEmpty) {
    throw const FormatException('Invalid checkout redirect.');
  }
  return redirect;
}

bool _isTrustedConsoleOrigin(Uri origin) {
  if (!origin.hasScheme || origin.host.isEmpty || origin.userInfo.isNotEmpty) {
    return false;
  }
  if (origin.scheme == 'https') return true;
  return origin.scheme == 'http' && _isLoopback(origin.host);
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized == '::1') return true;
  final octets = normalized.split('.');
  if (octets.length != 4) return false;
  final values = octets.map(int.tryParse).toList(growable: false);
  return values.every((value) => value != null && value >= 0 && value <= 255) &&
      values.first == 127;
}
