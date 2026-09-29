part of 'forge_device_heartbeat_persistence.dart';

/// The authority declaration carried by the persistence contract is always
/// offline. Keeping it as a value makes accidental authority claims visible.
class ForgeDeviceHeartbeatPersistenceAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceHeartbeatPersistenceAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  const ForgeDeviceHeartbeatPersistenceAuthority.offline()
    : identityVerified = false,
      heartbeatPersisted = false,
      inventoryAuthoritative = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false;

  factory ForgeDeviceHeartbeatPersistenceAuthority.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    _heartbeatExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceHeartbeatPersistenceAuthority(
      identityVerified: _heartbeatBool(json['identity_verified']),
      heartbeatPersisted: _heartbeatBool(json['heartbeat_persisted']),
      inventoryAuthoritative: _heartbeatBool(json['inventory_authoritative']),
      reservationCreated: _heartbeatBool(json['reservation_created']),
      executionAuthorized: _heartbeatBool(json['execution_authorized']),
      dispatchPerformed: _heartbeatBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge heartbeat persistence authority must be offline.',
      );
    }
    return authority;
  }

  bool get anyGranted =>
      identityVerified ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;
}

class ForgeDeviceHeartbeatPersistenceDevice {
  final String deviceID;
  final String tenantID;
  final String approvalState;

  const ForgeDeviceHeartbeatPersistenceDevice({
    required this.deviceID,
    required this.tenantID,
    required this.approvalState,
  });

  factory ForgeDeviceHeartbeatPersistenceDevice.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    _heartbeatExactKeys(json, {'device_id', 'tenant_id', 'approval_state'});
    final approval = _heartbeatText(json['approval_state']);
    if (!const {'approved', 'pending', 'revoked'}.contains(approval)) {
      throw const FormatException('Invalid Forge heartbeat device approval.');
    }
    return ForgeDeviceHeartbeatPersistenceDevice(
      deviceID: _heartbeatIdentifier(json['device_id']),
      tenantID: _heartbeatIdentifier(json['tenant_id']),
      approvalState: approval,
    );
  }
}
