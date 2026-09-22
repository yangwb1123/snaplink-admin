part of 'forge_conversations_api.dart';

extension ForgeConversationsApiClientInstanceResourceView
    on ForgeConversationsApi {
  /// Reads the owner-scoped client-instance/resource observation candidate.
  /// It is available only when an accepted device-fabric activation mounts
  /// the route; ordinary Forge construction keeps it unregistered.
  ///
  /// The response is a strict display-only composition. It never registers a
  /// client, authenticates a Runner, reserves a device, schedules, dispatches,
  /// or executes work.
  Future<ForgeClientInstanceResourceView>
  readClientInstanceResourceViewCandidate({
    required ForgeDeviceOwner owner,
  }) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    // Keep the reviewed candidate read one-shot on 401. Refresh/replay is
    // reserved for the ordinary owner conversation transport and must not
    // turn this opt-in metadata reader into an implicit second request.
    final root = await _requestJson(
      'GET',
      '/client-instances/resource-view',
      retryUnauthorized: false,
    );
    final view = ForgeClientInstanceResourceView.fromJson(root);
    if (view.owner != expectedOwner || !view.isDisplayOnly) {
      throw const FormatException(
        'Forge returned an invalid client-instance resource view.',
      );
    }
    return view;
  }
}
