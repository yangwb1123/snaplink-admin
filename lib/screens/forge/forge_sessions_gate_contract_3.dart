part of 'forge_sessions_gate.dart';

/// Typed documentation for the unchanged ForgeSessionsGate constructor surface.
abstract interface class _ForgeSessionsGateContract3 {
  /// Enables the explicitly reviewed metadata-only credential candidate for
  /// a test or candidate harness. Production construction keeps this false.
  bool get enableDeviceCredentialCandidate;

  /// Candidate-only origin for the credential lifecycle POST. It must be
  /// explicit when [enableDeviceCredentialCandidate] is true.
  String? get deviceCredentialCandidateApiOrigin;

  Widget Function(String)? get testScreenBuilder;

  Widget Function(String, String?)? get testScreenBuilderWithRoute;
}
