part of 'portal_screen.dart';

/// Notification wiring for the portal shell: a five-item preview list plus an
/// unread badge, refreshed from `/me/notifications` and kept live by the SSE
/// stream. Marking a preview read updates local state directly instead of
/// re-fetching the list and re-subscribing the stream.
extension _PortalScreenNotifications on _PortalScreenState {
  Future<void> _initializeNotifications() async {
    await _notificationSubscription?.cancel();
    try {
      final response = await _api.get(
        Uri(
          path: PortalPaths.notifications,
          queryParameters: const {'limit': '5'},
        ).toString(),
      );
      if (response.statusCode != 200 || !mounted) return;
      final body = PortalApi.decode(response);
      final items = _notificationObjects(body['notifications']);
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
      final response = await _api.post(PortalPaths.notificationRead(id));
      if (response.statusCode == 200 && mounted) {
        _update(() {
          final now = DateTime.now().toUtc().toIso8601String();
          _recentNotifications = [
            for (final item in _recentNotifications)
              if (item['id']?.toString() == id)
                {...item, 'read_at': now}
              else
                item,
          ];
          if (_notificationUnread > 0) _notificationUnread--;
        });
      }
    } catch (_) {
      // Navigation remains useful when notification persistence is unavailable.
    }
  }

  List<Map<String, dynamic>> _notificationObjects(Object? value) =>
      value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const <Map<String, dynamic>>[];

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
