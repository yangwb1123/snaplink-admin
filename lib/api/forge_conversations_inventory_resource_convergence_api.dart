part of 'forge_conversations_api.dart';

extension ForgeConversationsApiInventoryResourceConvergence
    on ForgeConversationsApi {
  /// Reads the owner-scoped v2 inventory and resource view as one bounded
  /// pair. Each source remains an authenticated GET-only candidate; owner,
  /// device identity, lifecycle counters, or shared resource-field drift
  /// fails closed before returning.
  Future<ForgeDeviceInventoryResourceConvergence>
  readConvergedInventoryResourceView({required ForgeDeviceOwner owner}) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final inventory = await readDeviceInventoryCandidateV2(
      owner: expectedOwner,
    );
    final resourceView = await readClientInstanceResourceViewCandidate(
      owner: expectedOwner,
    );
    final convergence = ForgeDeviceInventoryResourceConvergence.fromJson({
      'schema_version': forgeDeviceInventoryResourceConvergenceSchema,
      'evaluation_mode': forgeDeviceInventoryResourceConvergenceEvaluationMode,
      'inventory': inventory.toJson(),
      'resource_view': resourceView.toJson(),
      'converged': true,
      'read_only': true,
      'authority':
          const ForgeDeviceInventoryResourceConvergenceAuthority.offline()
              .toJson(),
    });
    if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
      throw const FormatException(
        'Forge returned an invalid inventory/resource convergence pair.',
      );
    }
    return convergence;
  }
}
