import 'forge_auth_profile.dart';

/// Explicitly optional read-only profile for a future owner-scoped device
/// observation client. The production Conversation OAuth surface deliberately
/// does not use this profile; the Snaplink seed keeps the matching client
/// inactive until a separate device-observation decision enables it.
abstract final class ForgeDeviceObservationOAuth {
  static const clientId = ForgeAuthProfile.deviceObservationClientId;
  static const resource = ForgeAuthProfile.resource;
  static const scopes = ForgeAuthProfile.deviceObservationClientScopes;
}
