part of 'portal_screen.dart';

extension _PortalScreenNotifications on _PortalScreenState {
  Future<void> _initializeNotifications() async {
    await _notificationSubscription?.cancel();
    try {
      final response = await _api.get('/me/notifications?limit=5');
      if (response.statusCode != 200 || !mounted) return;
      final body = PortalApi.decode(response);
      final items = (body['notifications'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _update(() {
        _recentNotifications = items.take(5).toList();
        _notificationUnread = (body['unread_count'] as num?)?.toInt() ?? 0;
      });
      _notificationSubscription = _api.notificationEvents().listen(
        _onNotification,
        onError: (_) {},
      );
    } catch (_) {
      // Notifications are optional; the rest of the portal remains available.
    }
  }

  void _onNotification(Map<String, dynamic> event) {
    if (!mounted) return;
    final id = event['id']?.toString();
    if (id != null &&
        _recentNotifications.any((item) => item['id']?.toString() == id)) {
      return;
    }
    _update(() {
      _recentNotifications = [event, ..._recentNotifications].take(5).toList();
      if (event['read_at'] == null) _notificationUnread++;
    });
  }

  Future<void> _stopNotifications() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  void _openNotification(Map<String, dynamic> notification) {
    final id = notification['id']?.toString();
    if (id != null && id.isNotEmpty && notification['read_at'] == null) {
      unawaited(_markNotificationRead(id));
    }
    final index = switch (notification['type']?.toString()) {
      'password_expiring' || 'password_leaked' || 'mfa_removed' => 1,
      'new_device_login' => 2,
      'session_expiring' => 3,
      'consent_granted' => 6,
      _ => 4,
    };
    _update(() => _navIndex = index);
  }

  Future<void> _markNotificationRead(String id) async {
    try {
      final response = await _api.post('/me/notifications/$id/read');
      if (response.statusCode == 200) await _initializeNotifications();
    } catch (_) {
      // Navigation remains useful when notification persistence is unavailable.
    }
  }

  Future<void> _completePendingAction() async {
    if (!_pendingAction.isAvailable || _actionHandled) return;
    final action = _pendingAction;
    _actionHandled = true;
    _pendingAction = const PortalActionRoute(kind: null, token: '');
    // The opaque verifier must not remain in browser history, the address
    // bar, copied links, or future referrers once this screen owns it. Scrub
    // before awaiting the mutation because a lost response has an unknown
    // outcome and must not trigger an automatic replay on refresh.
    BrowserNavigation.replaceState(portalLocationWithoutAction(_routeUri));
    final result = await action.complete(_api);
    if (!mounted) return;
    _update(() {
      _actionSucceeded = result.succeeded;
      _actionNotice = result.message;
      _navIndex = action.navigationIndex;
    });
  }
}
