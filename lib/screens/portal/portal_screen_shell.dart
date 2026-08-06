part of 'portal_screen.dart';

extension _PortalScreenShell on _PortalScreenState {
  List<NavigationRailDestination> _destinations(AppStrings strings) => [
    // 分组渲染：一级导航只显示 3 组，组内用壳层 SectionSelector。
    for (final group in _portalGroups) ...[
      NavigationRailDestination(
        icon: Icon(group.$1),
        selectedIcon: Icon(group.$2),
        label: Text(strings.translate(group.$3)),
      ),
    ],
  ];

  IconData _portalTabIcon(int tab) => switch (tab) {
    0 => Icons.dashboard_outlined,
    1 => Icons.shield_outlined,
    2 => Icons.devices_other_outlined,
    3 => Icons.devices_outlined,
    4 => Icons.history,
    5 => Icons.link_outlined,
    6 => Icons.apps_outlined,
    7 => Icons.business_outlined,
    8 => Icons.notifications_outlined,
    _ => Icons.privacy_tip_outlined,
  };

  String _portalTabLabel(int tab, AppStrings strings) => switch (tab) {
    0 => strings.overview,
    1 => strings.security,
    2 => strings.devices,
    3 => strings.sessions,
    4 => strings.activity,
    5 => strings.linkedIdentities,
    6 => strings.translate('Connected applications'),
    7 => strings.organizations,
    8 => strings.translate('Notifications'),
    _ => strings.privacy,
  };

  /// Portal 分组：Account / Connections / Data。
  static const _portalGroups = <(IconData, IconData, String)>[
    (Icons.person_outline, Icons.person, 'Account'),
    (Icons.link_outlined, Icons.link, 'Connections'),
    (Icons.data_usage_outlined, Icons.data_usage, 'Data'),
  ];

  /// 各 tab 的组归属（与 _destinations 顺序一致，用组标签作 key）。
  static const _portalTabGroups = [
    'Account', 'Account', 'Account', 'Account', 'Account', // overview..activity
    'Connections', 'Connections', 'Connections', // identities..notifications
    'Data', 'Data', // organizations, privacy
  ];

  static const _portalGroupTabs = <String, List<int>>{
    'Account': [0, 1, 2, 3, 4],
    'Connections': [5, 6, 7],
    'Data': [8, 9],
  };

  Widget _buildApp(BuildContext context) {
    final strings = AppStrings.of(context);
    final mySub = _me?['sub']?.toString() ?? '';
    final useCompactActions = MediaQuery.sizeOf(context).width < 520;
    final page = switch (_navIndex) {
      0 => OverviewTab(api: _api),
      1 => SecurityTab(api: _api),
      2 => DevicesTab(api: _api),
      3 => SessionsTab(
        api: _api,
        onCurrentSessionRevoked: _onCurrentSessionRevoked,
      ),
      4 => SecurityActivityTab(api: _api),
      5 => IdentitiesTab(api: _api),
      6 => ConsentsTab(api: _api),
      7 => OrganizationsTab(api: _api),
      8 => NotificationsTab(
        api: _api,
        onChanged: _initializeNotifications,
        onOpen: _openNotification,
      ),
      _ => PrivacyTab(
        api: _api,
        mySub: mySub,
        onAccountDeleted: _onAccountDeleted,
      ),
    };
    final currentGroup = _portalTabGroups[_navIndex];
    final groupTabs = _portalGroupTabs[currentGroup] ?? const <int>[0];
    return ResponsiveNavigationScaffold(
      selectedIndex: _portalGroups.indexWhere((g) => g.$3 == currentGroup),
      onDestinationSelected: (index) {
        if (index < 0 || index >= _portalGroups.length) return;
        final group = _portalGroups[index].$3;
        final tabs = _portalGroupTabs[group] ?? const <int>[0];
        final target = tabs.contains(_navIndex) ? _navIndex : tabs.first;
        if (target != _navIndex) _update(() => _navIndex = target);
      },
      destinations: _destinations(strings),
      drawerHeader: strings.accountTitle,
      body: Column(
        children: [
          if (_actionNotice != null)
            PortalActionNotice(
              message: _actionNotice!,
              succeeded: _actionSucceeded,
            ),
          Expanded(
            child: PageTransition(pageKey: ValueKey(_navIndex), child: page),
          ),
        ],
      ),
      appBar: AppBar(
        // 子菜单最上面一行（AppBar bottom，Material TabBar 模式）。
        bottom: groupTabs.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SectionSelector(
                    sections: [
                      for (final tab in groupTabs)
                        SectionDef('$tab', _portalTabLabel(tab, strings), _portalTabIcon(tab)),
                    ],
                    current: '$_navIndex',
                    onSelected: (id) {
                      final target = int.tryParse(id);
                      if (target != null && target != _navIndex) {
                        _update(() => _navIndex = target);
                      }
                    },
                  ),
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.accountTitle),
            if (mySub.isNotEmpty)
              Text(
                mySub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          NotificationBell(
            unreadCount: _notificationUnread,
            recent: _recentNotifications,
            onViewAll: () => _update(() => _navIndex = 8),
            onOpen: _openNotification,
          ),
          if (useCompactActions)
            IconButton(
              onPressed: _signOut,
              tooltip: strings.signOut,
              icon: const Icon(Icons.logout),
            )
          else
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: Text(strings.signOut),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
