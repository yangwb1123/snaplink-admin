Map<String, dynamic>? commerceRecord(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> commerceRecords(
  Map<String, dynamic> payload,
  String key,
) {
  final value = payload[key];
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((record) => Map<String, dynamic>.from(record))
      .toList(growable: false);
}

String commerceMinorUnits(Map<String, dynamic>? money) {
  if (money == null) return '—';
  final currency = money['currency']?.toString() ?? '';
  final amount = money['minor_units']?.toString() ?? '0';
  return '$currency $amount minor units'.trim();
}

String commerceGrant(Object? value) {
  if (value is! Map) return '—';
  if (value['unlimited'] == true) return 'Unlimited';
  final hard = value['hard'] ?? 0;
  final soft = value['soft'] ?? 0;
  return 'Hard $hard · soft $soft';
}

bool commerceSubscriptionIsLive(Map<String, dynamic> subscription) => const {
  'pending',
  'trialing',
  'active',
  'past_due',
  'paused',
}.contains(subscription['status']?.toString());

Map<String, dynamic> commercePlanRef(Map<String, dynamic> subscription) {
  final plan = subscription['plan'];
  return plan is Map ? Map<String, dynamic>.from(plan) : const {};
}

String commercePlanLabel(Map<String, dynamic> plan) {
  final name = plan['name']?.toString() ?? plan['id']?.toString() ?? 'Plan';
  final id = plan['id']?.toString() ?? '';
  final version = plan['version']?.toString() ?? '';
  return '$name · $id v$version';
}

String commerceIdempotencyKey(String operation) {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  return 'console-$operation-$now';
}
