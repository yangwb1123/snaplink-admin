import 'package:flutter/material.dart';

import '../../session.dart';
import '../../services/forge_conversations_api_origin.dart';
import '../../services/forge_conversations_oauth.dart';
import '../../services/browser_navigation.dart';
import 'forge_sessions_screen.dart';

class ForgeSessionsGate extends StatefulWidget {
  const ForgeSessionsGate({super.key});

  @override
  State<ForgeSessionsGate> createState() => _ForgeSessionsGateState();
}

class _ForgeSessionsGateState extends State<ForgeSessionsGate> {
  late final String? _token;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    _token = Session.readForClient(ForgeConversationsOAuth.clientId);
    if (_token == null) _redirectForSignIn();
  }

  void _redirectForSignIn() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BrowserNavigation.replaceLocation(
          ForgeConversationsOAuth.loginLocation(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ForgeSessionsScreen(
      accessToken: token,
      apiOrigin: ForgeConversationsApiOrigin.baseUrl,
    );
  }
}
