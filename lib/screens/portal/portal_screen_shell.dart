part of 'portal_screen.dart';

extension _PortalScreenShell on _PortalScreenState {
  List<NavigationRailDestination> _destinations(AppStrings strings) => [
    NavigationRailDestination(
      icon: const Icon(Icons.person_outline),
      label: Text(strings.overview),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.lock_outline),
      label: Text(strings.security),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.devices_other_outlined),
      label: Text(strings.devices),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.devices_outlined),
      label: Text(strings.sessions),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.security_outlined),
      label: Text(strings.activity),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.link_outlined),
      label: Text(strings.linkedIdentities),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.apps_outlined),
      label: Text(strings.connectedApps),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.business_outlined),
      label: Text(strings.organizations),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.notifications_outlined),
      label: Text(strings.translate('Notifications')),
    ),
    NavigationRailDestination(
      icon: const Icon(Icons.privacy_tip_outlined),
      label: Text(strings.privacy),
    ),
  ];

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
    return ResponsiveNavigationScaffold(
      selectedIndex: _navIndex,
      onDestinationSelected: (index) {
        if (index != _navIndex) _update(() => _navIndex = index);
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
          Expanded(child: page),
        ],
      ),
      appBar: AppBar(
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
