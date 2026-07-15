import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../session.dart';
import '../../sso_client.dart';
import 'clients_tab.dart';
import 'users_tab.dart';
import 'tenants_tab.dart';

class DashboardScreen extends StatefulWidget {
  final SSOAdminClient client;
  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.apps), label: Text('Clients')),
    NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
    NavigationRailDestination(icon: Icon(Icons.business), label: Text('Tenants')),
  ];

  void _logout() {
    widget.client.logout();
    Session.clear();
    // A real navigation, not Navigator — matches every other transition in
    // this auth flow, and guarantees no stale in-memory state survives.
    web.window.location.href = '/login/';
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      0 => ClientsTab(client: widget.client),
      1 => UsersTab(client: widget.client),
      _ => TenantsTab(client: widget.client),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSO Admin'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: '登出'),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
