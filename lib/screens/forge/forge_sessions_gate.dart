import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/forge_conversations_api_origin.dart';
import '../../services/forge_conversations_oauth.dart';
import '../../services/forge_credential_store.dart';
import '../../services/browser_navigation.dart';
import 'forge_sessions_screen.dart';

class ForgeSessionsGate extends StatefulWidget {
  final ForgeCredentialStore? credentialStore;
  @visibleForTesting
  final Widget Function(String accessToken)? testScreenBuilder;

  const ForgeSessionsGate({
    super.key,
    this.credentialStore,
    this.testScreenBuilder,
  });

  @override
  State<ForgeSessionsGate> createState() => _ForgeSessionsGateState();
}

class _ForgeSessionsGateState extends State<ForgeSessionsGate> {
  late final ForgeCredentialStore _credentialStore =
      widget.credentialStore ?? ForgeCredentialStore();
  String? _token;
  bool _loading = true;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    String? token;
    try {
      token = await _credentialStore.restore();
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    setState(() {
      _token = token;
      _loading = false;
    });
    if (token == null) _redirectForSignIn();
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final testScreenBuilder = widget.testScreenBuilder;
    if (testScreenBuilder != null) return testScreenBuilder(token);
    return ForgeSessionsScreen(
      accessToken: token,
      apiOrigin: ForgeConversationsApiOrigin.baseUrl,
    );
  }
}
