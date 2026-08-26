import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';

/// 模块强调色（identity 组 indigo-violet）：详情头部与子资源图标统一按组色上色。
Color _userAccent() => adminModuleIconColor('users');

Map<String, dynamic> _record(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
String _value(dynamic value) => value?.toString() ?? '';
String _short(String value, {int max = 120}) =>
    value.length <= max ? value : '${value.substring(0, max)}…';

/// IDs remain API values, not translation keys. The tooltip preserves the
/// complete value when a narrow card has to ellipsize it.
Widget _longValue(String value, {bool bold = false}) => Tooltip(
  message: value,
  child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
      style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
);
Widget _resourceCard(BuildContext context, {required String title,
  required IconData icon, int? count, required List<Widget> children}) => Card(
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Row(
      children: [Icon(icon, size: 20, color: _userAccent()),
        const SizedBox(width: 8), Expanded(child: LocalizedText(title,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium)),
        if (count != null) ...[const SizedBox(width: 8),
          Chip(label: Text('$count'), visualDensity: VisualDensity.compact)],
      ],
    )),
    const Divider(height: 1), ...children,
  ]),
);

Widget _avatar(IconData icon) => CircleAvatar(
  backgroundColor: _userAccent().withValues(alpha: 0.12),
  foregroundColor: _userAccent(), child: Icon(icon, size: 20));

Widget _dangerButton(BuildContext context, String label, VoidCallback? action) =>
    TextButton(onPressed: action, style: TextButton.styleFrom(
      foregroundColor: AppColors.semanticFor(Theme.of(context).brightness,
          AppColors.danger)), child: LocalizedText(label));

Widget _emptyResource(IconData icon, String title) => ListView(
  padding: const EdgeInsets.all(16),
  children: [Card(child: EmptyState(variant: EmptyStateVariant.empty,
    icon: icon, title: title, compact: true))],
);

/// Shared card/list shell for optional user resources.
class _UserResourceList extends StatelessWidget {
  final String title, emptyTitle;
  final IconData icon;
  final List<dynamic> items;
  final Widget Function(BuildContext, dynamic) itemBuilder;
  const _UserResourceList({required this.title, required this.emptyTitle,
    required this.icon, required this.items, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyResource(icon, emptyTitle);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _resourceCard(context, title: title, icon: icon, count: items.length,
        children: ListTile.divideTiles(context: context,
          tiles: [for (final item in items) itemBuilder(context, item)]).toList()),
    ]);
  }
}

class UserDetailHeader extends StatelessWidget {
  final Map<String, dynamic>? user;
  const UserDetailHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _userAccent().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, size: 32, color: _userAccent()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _longValue(_value(user?['id']), bold: true),
                LocalizedText('Provider: {provider}', args: {'provider': user?['provider'] ?? ''}, maxLines: 2, overflow: TextOverflow.ellipsis),
                LocalizedText('External ID: {external_id}', args: {'external_id': user?['externalId'] ?? user?['external_id'] ?? ''}, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (user?['status'] case final status?)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: status == 'active'
                  ? StatusChip.active(label: context.tr('active'))
                  : StatusChip.inactive(label: _value(status)),
            ),
        ],
      ),
    ),
  );
}

class UserDetailTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const UserDetailTabBar({super.key, required this.labels,
    required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: labels[i],
                child: ChoiceChip(
                  label: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: selectedIndex == i,
                  onSelected: (_) => onSelected(i),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Sessions use a card/list rather than a wide optional-resource table.
class UserSessionsView extends StatelessWidget {
  final List<dynamic> sessions;
  const UserSessionsView({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) => _UserResourceList(
    title: 'Active sessions',
    emptyTitle: 'No active sessions',
    icon: Icons.devices,
    items: sessions,
    itemBuilder: (context, raw) {
      final session = _record(raw);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _avatar(Icons.devices),
        title: _longValue(_value(session['id']), bold: true),
        subtitle: LocalizedText(
          'IP: {address}  UA: {agent}',
          args: {
            'address': session['ip'] ?? '',
            'agent': _short(_value(session['user_agent'])),
          },
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    },
  );
}

/// Consents are card/list rows; the screen still owns confirmation and DELETE.
class UserConsentsView extends StatelessWidget {
  final List<dynamic> consents;
  final bool mutating;
  final ValueChanged<String> onRevoke;
  const UserConsentsView({
    super.key,
    required this.consents,
    required this.mutating,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => _UserResourceList(
    title: 'Application consents',
    emptyTitle: 'No consents granted',
    icon: Icons.checklist,
    items: consents,
    itemBuilder: (context, raw) {
      final consent = _record(raw);
      final clientId = _value(consent['client_id']);
      final scopes = consent['scopes'] is List
          ? (consent['scopes'] as List).map(_value).join(', ')
          : _value(consent['scopes']);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _avatar(Icons.policy_outlined),
        title: _longValue(clientId, bold: true),
        subtitle: Text(
          scopes,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        trailing: _dangerButton(
          context,
          'Revoke',
          mutating ? null : () => onRevoke(clientId),
        ),
      );
    },
  );
}

/// MFA factors are a compact card/list; removal confirmation remains in screen.
class UserMfaView extends StatelessWidget {
  final List<dynamic> factors;
  final bool mutating;
  final ValueChanged<String> onRemove;
  const UserMfaView({
    super.key,
    required this.factors,
    required this.mutating,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => _UserResourceList(
    title: 'Second factors',
    emptyTitle: 'No MFA factors registered',
    icon: Icons.security,
    items: factors,
    itemBuilder: (context, raw) {
      final factor = _record(raw);
      final label = _value(factor['label']).isNotEmpty
          ? _value(factor['label'])
          : _value(factor['method']);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _avatar(Icons.security),
        title: _longValue(label, bold: true),
        subtitle: Text(
          _value(factor['method']),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _dangerButton(
          context,
          'Remove',
          mutating ? null : () => onRemove(_value(factor['id'])),
        ),
      );
    },
  );
}

/// Lifecycle is a small vertical timeline of current state and transitions.
class UserLifecycleView extends StatelessWidget {
  final Map<String, dynamic> lifecycle;
  final bool showBackButton;
  final VoidCallback onBack;
  const UserLifecycleView({
    super.key,
    required this.lifecycle,
    required this.showBackButton,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final state = lifecycle['state']?.toString() ?? 'active';
    final transitions =
        (lifecycle['allowed_transitions'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _resourceCard(
          context,
          title: 'Account lifecycle',
          icon: Icons.route,
          children: [
            _timelineStep(
              context,
              icon: Icons.radio_button_checked,
              isLast: transitions.isEmpty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    'Current state: {state}',
                    args: {'state': state},
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StatusChip.info(label: state),
                ],
              ),
            ),
            if (transitions.isNotEmpty)
              _timelineStep(
                context,
                icon: Icons.alt_route,
                isLast: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalizedText('Allowed transitions:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final transition in transitions)
                          Tooltip(
                            message: transition,
                            child: Chip(
                              label: Text(
                                transition,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (showBackButton) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const LocalizedText('Back to user list'),
          ),
        ],
      ],
    );
  }
}

Widget _timelineStep(
  BuildContext context, {
  required IconData icon,
  required bool isLast,
  required Widget child,
}) {
  final line = Theme.of(context).colorScheme.outlineVariant;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 32,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (!isLast)
              Positioned(
                top: 16,
                bottom: 0,
                child: Container(width: 2, color: line),
              ),
            Icon(icon, size: 22, color: _userAccent()),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
          child: child,
        ),
      ),
    ],
  );
}
