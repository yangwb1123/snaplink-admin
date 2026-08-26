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
    6 => strings.connectedApps,
    7 => strings.organizations,
    8 => strings.notifications,
    _ => strings.privacy,
  };

  /// Portal 分组：Account / Connections / Data。
  static const _portalGroups = <(IconData, IconData, String)>[
    (Icons.person_outline, Icons.person, 'Account'),
    (Icons.link_outlined, Icons.link, 'Connections'),
    (Icons.data_usage_outlined, Icons.data_usage, 'Data'),
  ];

  /// 各 tab 的组归属（与 _destinations 顺序一致，用组标签作 key）。
  /// Tab 顺序保留既有 deep-link 索引：notifications 位于 organizations
  /// 之后，因此不能按连续区间推导 Connections/Data。
  static const _portalTabGroups = [
    'Account', 'Account', 'Account', 'Account', 'Account', // overview..activity
    'Connections', 'Connections', // identities, connected apps
    'Data', // organizations
    'Connections', // notifications
    'Data', // privacy
  ];

  static const _portalGroupTabs = <String, List<int>>{
    'Account': [0, 1, 2, 3, 4],
    'Connections': [5, 6, 8],
    'Data': [7, 9],
  };

  void _selectDestination(int index) {
    if (index < 0 || index >= _portalGroups.length) return;
    final group = _portalGroups[index].$3;
    final tabs = _portalGroupTabs[group] ?? const <int>[0];
    final target = tabs.contains(_navIndex) ? _navIndex : tabs.first;
    if (target != _navIndex) _update(() => _navIndex = target);
  }

  void _selectTab(String id) {
    final target = int.tryParse(id);
    if (target != null && target != _navIndex) {
      _update(() => _navIndex = target);
    }
  }

  List<SectionDef> _groupSections(
    BuildContext context,
    List<int> groupTabs,
    AppStrings strings,
  ) => [
    for (final tab in groupTabs)
      SectionDef(
        '$tab',
        _portalTabLabel(tab, strings),
        _portalTabIcon(tab),
        // 品牌强调色：组内子菜单芯片图标与品牌色一致。
        color: Theme.of(context).colorScheme.primary,
      ),
  ];

  Widget _groupSelector(
    BuildContext context,
    List<int> groupTabs,
    AppStrings strings,
  ) {
    if (groupTabs.length > 1) {
      return ConstrainedBox(
        // 首次布局即给 bounded 宽度（NavigationToolbar 首帧无界
        // 测量导致 SCSV 全宽——子菜单文字超出屏幕，二次才修正）。
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 180,
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SectionSelector(
              sections: _groupSections(context, groupTabs, strings),
              current: '$_navIndex',
              onSelected: _selectTab,
            ),
          ),
        ),
      );
    }
    // 单 tab 组：直接显示该 tab 的标签，而非账户标题。
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        _portalTabLabel(groupTabs.single, strings),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

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
      onDestinationSelected: _selectDestination,
      destinations: _destinations(strings),
      drawerHeader: strings.accountTitle,
      body: Column(
        children: [
          if (_actionNotice != null)
            PortalActionNotice(
              message: _actionNotice!,
              succeeded: _actionSucceeded,
            ),
          // 页面级边界：单 tab 构建崩溃 → 兜底 UI，壳层导航/通知/登出仍可用
          // （与 admin/dashboard_page_resolution 的每模块页边界同一粒度）。
          Expanded(
            child: PageTransition(
              pageKey: ValueKey(_navIndex),
              child: ErrorBoundary(child: page),
            ),
          ),
        ],
      ),
      appBar: AppBar(
        // 左上角：品牌 logo（点击开抽屉）。
        // leadingWidth = NavigationRail 宽度（80）：logo 中心与侧边栏
        // 图标中心同一条垂直对齐线；左缘与 rail 左缘同线。
        leadingWidth: 80,
        leading: Center(
          child: BrandLogo(
            onTap: () {
              final scaffold = Scaffold.of(context);
              if (scaffold.hasDrawer) scaffold.openDrawer();
            },
          ),
        ),
        titleSpacing: 8,
        // 子菜单与通知/登出同一行（AppBar 行），靠左占满 title 区。
        title: _groupSelector(context, groupTabs, strings),
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
