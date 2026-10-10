/// Published webhook deliveries embed the audit event and last_error.
/// Flat keys remain accepted for older proxy responses.
String? webhookDeadLetterType(Map record) {
  final event = record['event'];
  return (record['event_type'] ??
          record['type'] ??
          (event is Map ? event['type'] ?? event['event_type'] : null))
      ?.toString();
}

String webhookDeadLetterError(Map record) =>
    (record['last_error'] ?? record['error'])?.toString() ?? '';
