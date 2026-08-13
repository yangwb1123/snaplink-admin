import 'dcr_models.dart';

/// Projection of an RFC 7592 PUT response onto the manage form's working
/// copy, keeping the lossless round-trip guarantee intact.
///
/// The response body is authoritative for every field the server echoes.
/// Fields the server omits are back-filled from the metadata this process
/// just validated and submitted, so an older replica that skips some keys
/// cannot silently degrade the next save.
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
