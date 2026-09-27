part of 'forge_conversations_api.dart';

extension ForgeConversationsApiClientInstanceSessionResourceConvergence
    on ForgeConversationsApi {
  /// Reads the owner-bound session and resource views as one explicit pair.
  /// Each source remains an authenticated GET-only candidate; owner or
  /// instance-row drift fails closed before the shared Sessions surface sees
  /// either observation.
  Future<ForgeClientInstanceSessionResourceConvergence>
  readConvergedClientInstanceViews({required ForgeDeviceOwner owner}) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final sessionView = await readClientInstanceSessionViewCandidate(
      owner: expectedOwner,
    );
    final resourceView = await readClientInstanceResourceViewCandidate(
      owner: expectedOwner,
    );
    final convergence = ForgeClientInstanceSessionResourceConvergence.fromJson({
      'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
      'evaluation_mode':
          forgeClientInstanceSessionResourceConvergenceEvaluationMode,
      'session_view': sessionView.toJson(),
      'resource_view': resourceView.toJson(),
      'converged': true,
      'read_only': true,
      'authority':
          const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
              .toJson(),
    });
    if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
      throw const FormatException(
        'Forge returned an invalid client-instance session/resource pair.',
      );
    }
    return convergence;
  }
}
