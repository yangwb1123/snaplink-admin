import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import '../../i18n/app_strings.dart';

/// AppBar notification bell: animated unread badge, up to five preview items
/// (colored read/unread affordance), and a "view all" action that opens the
/// inbox tab. Preview rows keep API values raw ([Text]) while static copy
/// runs through [AppStrings] lookup.
class NotificationBell extends StatelessWidget {
  final int unreadCount;
  final List<Map<String, dynamic>> recent;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.recent,
    required this.onViewAll,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: context.tr('Notifications'),
      onSelected: (index) {
        if (index < 0) {
          onViewAll();
        } else {
          onOpen(recent[index]);
        }
      },
      itemBuilder: (context) => [
        if (recent.isEmpty)
          PopupMenuItem(
            enabled: false,
            child: SizedBox(
              width: 280,
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(context.tr('You have no notifications.')),
                  ),
                ],
              ),
            ),
          )
        else
          for (var index = 0; index < recent.length && index < 5; index++)
            PopupMenuItem(
              value: index,
              child: _BellPreview(item: recent[index]),
            ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.inbox_outlined,
              size: 18,
              color: scheme.primary,
            ),
            title: Text(context.tr('View all notifications')),
          ),
        ),
      ],
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unreadCount > 0)
            Positioned(
              right: -8,
              top: -7,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Transform.scale(
                  scale: 0.5 + 0.5 * value,
                  child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One preview row inside the popup: unread rows get a brand dot + bold
/// title, read rows a muted outline icon.
class _BellPreview extends StatelessWidget {
  final Map<String, dynamic> item;
  const _BellPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = item['read_at'] == null;
    return SizedBox(
      width: 280,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          unread ? Icons.circle : Icons.notifications_outlined,
          size: 14,
          color: unread ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(
          item['title']?.toString() ?? context.tr('Security notification'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : null),
        ),
        subtitle: Text(
          item['body']?.toString() ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
