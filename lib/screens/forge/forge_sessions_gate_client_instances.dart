part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateClientInstances on _ForgeSessionsGateState {
  void _configureClientInstanceResourceViewCandidate(String? token) {
    final owner = widget.clientInstanceResourceViewOwner;
    if (token == null ||
        !widget.enableClientInstanceResourceViewCandidate ||
        widget.clientInstanceResourceViewReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceResourceViewCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _clientInstanceResourceViewCandidateApi = api;
    _clientInstanceResourceViewCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeClientInstanceResourceView>.error(
          const FormatException(
            'Forge client-instance/resource-view owner binding changed.',
          ),
        );
      }
      return api.readClientInstanceResourceViewCandidate(owner: owner);
    };
  }

  void _configureClientInstanceSessionViewCandidate(String? token) {
    final owner = widget.clientInstanceSessionViewOwner;
    if (token == null ||
        !widget.enableClientInstanceSessionViewCandidate ||
        widget.clientInstanceSessionViewReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceSessionViewCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
      useWallClockTimeout: true,
    );
    _clientInstanceSessionViewCandidateApi = api;
    _clientInstanceSessionViewCandidateReader = (requestedOwner) {
      if (requestedOwner != owner) {
        return Future<ForgeClientInstanceSessionView>.error(
          const FormatException(
            'Forge client-instance/session-view owner binding changed.',
          ),
        );
      }
      return api.readClientInstanceSessionViewCandidate(owner: owner);
    };
  }

  void _configureClientInstanceSessionResourceConvergenceCandidate(
    String? token,
  ) {
    final owner = widget.clientInstanceSessionResourceConvergenceOwner;
    if (token == null ||
        !widget.enableClientInstanceSessionResourceConvergenceCandidate ||
        widget.clientInstanceSessionResourceConvergenceReader != null ||
        owner == null) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl:
          widget.clientInstanceSessionResourceConvergenceCandidateApiOrigin ??
          ForgeConversationsApiOrigin.baseUrl,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _clientInstanceSessionResourceConvergenceCandidateApi = api;
    _clientInstanceSessionResourceConvergenceCandidateReader =
        (requestedOwner) {
          if (requestedOwner != owner) {
            return Future<ForgeClientInstanceSessionResourceConvergence>.error(
              const FormatException(
                'Forge client-instance session/resource owner binding changed.',
              ),
            );
          }
          return api.readConvergedClientInstanceViews(owner: owner);
        };
  }
}
