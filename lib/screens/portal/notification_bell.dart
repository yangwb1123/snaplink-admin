import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';

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
  Widget build(BuildContext context) => PopupMenuButton<int>(
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
          child: Text(context.tr('You have no notifications.')),
        )
      else
        for (var index = 0; index < recent.length && index < 5; index++)
          PopupMenuItem(
            value: index,
            child: SizedBox(
              width: 280,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  recent[index]['read_at'] == null
                      ? Icons.circle
                      : Icons.notifications_outlined,
                  size: 14,
                ),
                title: Text(
                  recent[index]['title']?.toString() ??
                      context.tr('Security notification'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  recent[index]['body']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: -1,
        child: Text(context.tr('View all notifications')),
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
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
