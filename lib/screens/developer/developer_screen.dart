import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';
import 'dcr_models.dart';
import 'developer_api.dart';
import 'discovery_region_notice.dart';
import 'manage_panel.dart';
import 'register_panel.dart';

/// Developer Portal — lets a developer self-service register and manage
/// their own OAuth 2.0 / OIDC client application via Dynamic Client
/// Registration (RFC 7591/7592).
///
/// There is no developer account/login for this screen: the "Register a
/// New App" tab's POST /register is unauthenticated (or gated by an
/// optional operator-issued initial access token), and the "Manage an
/// Existing App" tab authenticates every GET/PUT/DELETE solely with the
/// registration_access_token that /register returned — the developer
/// pastes that token back in (or arrives here straight from a fresh
/// registration via "Manage This App").
class DeveloperScreen extends StatefulWidget {
  final DeveloperApi? api;

  const DeveloperScreen({super.key, this.api});

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
  late final DeveloperApi _api = widget.api ?? DeveloperApi();
  DcrDiscovery? _discovery;
  String? _discoveryError;
  bool _loadingDiscovery = true;

  @override
  void initState() {
    super.initState();
    _loadDiscovery();
  }

  Future<void> _loadDiscovery() async {
    setState(() {
      _loadingDiscovery = true;
      _discoveryError = null;
    });
    try {
      final discovery = await _api.loadDiscovery();
      if (mounted) {
        setState(() {
          _discovery = discovery;
          _discoveryError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _discoveryError =
              'OpenID Provider discovery is temporarily unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDiscovery = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Mirrors app.js's register-manage-btn handler: pivot straight to the
  // Manage tab and load the just-registered app so the developer doesn't
  // have to re-type what was just issued.
  void _openManageWithApp(
    String clientId,
    String token,
    Map<String, dynamic> registrationSnapshot,
  ) {
    _tabController.animateTo(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manageKey.currentState?.loadWithRegistration(
        clientId,
        token,
        registrationSnapshot,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(container: true, header: true, child: Text(strings.developerPortal)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: Icon(Icons.app_registration, color: scheme.primary),
              text: strings.registerNewApp,
            ),
            Tab(
              icon: Icon(
                Icons.manage_accounts_outlined,
                color: scheme.primary,
              ),
              text: strings.manageExistingApp,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Discovery load state: thin brand progress strip while the
          // well-known document is being fetched.
          if (_loadingDiscovery)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          if (_discoveryError != null)
            MaterialBanner(
              content: Semantics(
                liveRegion: true,
                child: Text(context.tr(_discoveryError!)),
              ),
              leading: Icon(
                Icons.cloud_off_outlined,
                color: scheme.error,
              ),
              actions: [
                TextButton.icon(
                  onPressed: _loadingDiscovery ? null : _loadDiscovery,
                  icon: _loadingDiscovery
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh, color: scheme.primary),
                  label: Text(strings.retryDiscovery),
                ),
              ],
            ),
          // Loaded: region provenance notice when discovery advertises one.
          if (_discovery?.servingRegion.isNotEmpty == true)
            DiscoveryRegionNotice(servingRegion: _discovery!.servingRegion),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RegisterPanel(
                  api: _api,
                  discovery: _discovery,
                  onManage: _openManageWithApp,
                ),
                ManagePanel(key: _manageKey, api: _api, discovery: _discovery),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
