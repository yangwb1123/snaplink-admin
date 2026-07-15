import 'package:flutter/material.dart';
import 'developer_api.dart';
import 'manage_panel.dart';
import 'register_panel.dart';

/// Developer Portal — lets a developer self-service register and manage
/// their OWN OAuth 2.0 / OIDC client application via Dynamic Client
/// Registration (RFC 7591/7592). Ported 1:1 from
/// interfaces/web/developer/{index.html,app.js}.
///
/// There is no developer account/login for this screen: the "Register a
/// New App" tab's POST /register is unauthenticated (or gated by an
/// optional operator-issued initial access token), and the "Manage an
/// Existing App" tab authenticates every GET/PUT/DELETE solely with the
/// registration_access_token that /register returned — the developer
/// pastes that token back in (or arrives here straight from a fresh
/// registration via "Manage This App").
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final _manageKey = GlobalKey<ManagePanelState>();
  final DeveloperApi _api = DeveloperApi();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Mirrors app.js's register-manage-btn handler: pivot straight to the
  // Manage tab and load the just-registered app so the developer doesn't
  // have to re-type what was just issued.
  void _openManageWithApp(String clientId, String token) {
    _tabController.animateTo(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manageKey.currentState?.loadWith(clientId, token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Portal'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Register a New App'),
            Tab(text: 'Manage an Existing App'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RegisterPanel(api: _api, onManage: _openManageWithApp),
          ManagePanel(key: _manageKey, api: _api),
        ],
      ),
    );
  }
}
