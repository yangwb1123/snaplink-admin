import 'dcr_models.dart';

class DcrUpdateProjection {
  final Map<String, dynamic> wire;
  final DcrRoundTripSafety safety;

  const DcrUpdateProjection({required this.wire, required this.safety});

  factory DcrUpdateProjection.fromPutResponse({
    required Map<String, dynamic> response,
    required DcrClientMetadata submitted,
  }) {
    final wire = Map<String, dynamic>.from(response)
      ..remove('client_secret')
      ..remove('registration_access_token');

    // Current servers return these fields. The fallbacks preserve only values
    // this process just validated when talking to an older replica.
    wire.putIfAbsent('grant_types', () => submitted.grantTypes);
    wire.putIfAbsent('response_types', () => submitted.responseTypes);
    wire.putIfAbsent('contacts', () => submitted.contacts);
    if (submitted.tenantId.isNotEmpty) {
      wire.putIfAbsent('tenant_id', () => submitted.tenantId);
    }

    return DcrUpdateProjection(
      wire: wire,
      safety: DcrRoundTripSafety.fromWire(
        wire,
        trustedRegistrationSnapshot: true,
      ),
    );
  }
}
