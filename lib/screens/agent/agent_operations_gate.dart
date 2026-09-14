import 'package:flutter/material.dart';

import '../../session.dart';
import '../../services/agent_hub_api_origin.dart';
import '../../services/agent_hub_oauth.dart';
import '../../services/browser_navigation.dart';
import '../../widgets/error_boundary.dart';
import 'agent_operations_screen.dart';

/// Keeps the Agent Hub audience request separate from identity-session/device
/// management. A Hub 401 expires the shared bearer; a 403 is rendered in the
/// Agent area so the user can request the additional scopes explicitly.
class AgentOperationsGate extends StatefulWidget {
  const AgentOperationsGate({super.key});

  @override
  State<AgentOperationsGate> createState() => _AgentOperationsGateState();
}

class _AgentOperationsGateState extends State<AgentOperationsGate> {
  late final String? _token;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    _token = Session.read();
    if (_token == null) _redirectForSignIn();
  }

  void _redirectForSignIn() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BrowserNavigation.replaceLocation(AgentHubOAuth.loginLocation());
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ErrorBoundary(
      child: AgentOperationsScreen(
        accessToken: token,
        apiOrigin: AgentHubApiOrigin.baseUrl,
      ),
    );
  }
}
