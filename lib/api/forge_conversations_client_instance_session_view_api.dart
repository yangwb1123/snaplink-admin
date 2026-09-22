part of 'forge_conversations_api.dart';

extension ForgeConversationsApiClientInstanceSessionView
    on ForgeConversationsApi {
  /// Reads the owner-scoped client-instance/session observation candidate.
  /// It is available only when an accepted device-fabric activation mounts
  /// the route; ordinary Forge construction keeps it unregistered.
  ///
  /// The response is a strict display-only owner-bound value. It never
  /// registers a client instance, writes a Prompt, creates a Run, discovers a
  /// device, schedules, dispatches, or executes work.
  Future<ForgeClientInstanceSessionView>
  readClientInstanceSessionViewCandidate({
    required ForgeDeviceOwner owner,
  }) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    // Candidate reads remain one-shot at an authorization boundary. A
    // caller-supplied token refresh belongs to the owner session transport;
    // replaying this opt-in candidate could silently cross the reviewed
    // origin/owner boundary after a 401.
    final root = await _requestJson(
      'GET',
      '/client-instances/session-view',
      retryUnauthorized: false,
    );
    final view = ForgeClientInstanceSessionView.fromJson(root);
    if (view.owner != expectedOwner || !view.isDisplayOnly) {
      throw const FormatException(
        'Forge returned an invalid client-instance session view.',
      );
    }
    return view;
  }
}
