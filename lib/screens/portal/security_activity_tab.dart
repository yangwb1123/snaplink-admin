import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/timeline_list.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';

import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

class SecurityActivityTab extends StatefulWidget {
  final PortalApi api;

  const SecurityActivityTab({super.key, required this.api});

  @override
  State<SecurityActivityTab> createState() => _SecurityActivityTabState();
}

class _SecurityActivityTabState extends State<SecurityActivityTab> {
  bool _activityLoading = true;
  bool _historyLoading = true;
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _history = const [];
  String? _activityError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _loadActivity();
    _loadHistory();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final response = await widget.api.get(
        PortalSecurityPaths.securityActivity,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _events = portalObjectList(PortalApi.decode(response), 'events');
        });
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() => _activityError = 'Security activity is not enabled.');
      } else {
        setState(() => _activityError = 'Could not load security activity.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _activityError = 'Could not load security activity.');
      }
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final response = await widget.api.get(PortalSecurityPaths.loginHistory);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _history = portalObjectList(
            PortalApi.decode(response),
            'login_history',
          );
        });
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() => _historyError = 'Login history is not enabled.');
      } else {
        setState(() => _historyError = 'Could not load login history.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = 'Could not load login history.');
      }
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PullToRefresh(
    onRefresh: _loadAll,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      context.tr('Security activity'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    'Recent sign-in and security events on your account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Review new devices, locations, and recent authentication history.',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr('Refresh activity'),
              onPressed: _activityLoading || _historyLoading ? null : _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PortalCard(
          title: 'Security timeline',
          children: [
            if (_activityLoading)
              const LinearProgressIndicator()
            else if (_activityError != null)
              MessageBanner(_activityError)
            else if (_events.isEmpty)
              const EmptyHint('No security events have been recorded.')
            else
              TimelineList(
                items: [for (final event in _events) _toTimelineItem(event)],
              ),
          ],
        ),
        PortalCard(
          title: 'Login history',
          children: [
            if (_historyLoading)
              const LinearProgressIndicator()
            else if (_historyError != null)
              MessageBanner(_historyError)
            else if (_history.isEmpty)
              const EmptyHint('No login history has been recorded.')
            else
              TimelineList(
                items: [for (final record in _history) _toHistoryItem(record)],
              ),
          ],
        ),
      ],
    ),
  );
}

/// 事件 → 时间线条目（语义色编码：新设备/新位置 = 警告）。
TimelineItem _toTimelineItem(Map<String, dynamic> event) {
  final type = event['type']?.toString() ?? 'activity';
  final risky = type == 'new_device' || type == 'new_location';
  return TimelineItem(
    icon: risky ? Icons.shield_outlined : Icons.history,
    color: risky ? AppColors.warning : null,
    title: _eventTitle(type),
    subtitle: _join([
      formatServerTime(event['time']),
      event['detail'],
      event['location'],
      event['ip'],
      event['trust_label'],
    ]),
  );
}

/// 登录记录 → 时间线条目（成功/失败色编码）。
TimelineItem _toHistoryItem(Map<String, dynamic> record) {
  final success = record['success'] != false;
  final flags = <String>[
    if (record['device_is_new'] == true) 'new device',
    if (record['location_is_new'] == true) 'new location',
  ];
  return TimelineItem(
    icon: success ? Icons.login_outlined : Icons.gpp_bad_outlined,
    color: success ? null : AppColors.danger,
    title: success ? 'Successful login' : 'Failed login',
    subtitle: _join([
      formatServerTime(record['time']),
      record['device'],
      ...flags,
    ]),
  );
}

String _eventTitle(String type) => switch (type) {
  'new_device' => 'New device detected',
  'new_location' => 'New location detected',
  'device_registered' => 'Device registered',
  'login' => 'Login',
  _ => type.replaceAll('_', ' '),
};

String _join(Iterable<Object?> values) => values
    .where((value) => value?.toString().isNotEmpty == true)
    .map((value) => value.toString())
    .join(' · ');
