import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/services/connectivity_service.dart';

/// Offline banner widget that shows when the browser goes offline.
///
/// Place at the top of the widget tree (e.g., in dashboard_screen)
/// to get a non-intrusive "You are offline" message.
class OfflineBanner extends StatefulWidget {
  /// 包在横幅之下的应用内容（离线时横幅置于其顶部）。
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _connectivity = ConnectivityService();
  late StreamSubscription<bool> _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _offline = !_connectivity.isOnline;
    _sub = _connectivity.onStatusChanged.listen((online) {
      if (mounted) setState(() => _offline = !online);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_offline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            content: Text(
              context.tr('You are offline. Some features may be unavailable.'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            leading: Icon(Icons.wifi_off, color: AppColors.warning),
            // 警告色 tint 叠表面（与 StatusChip 同语言）：浅/深色模式均
            // 保证正文对比度 ≥4.5（白色正文叠实色 amber 仅 ≈3.2）。
            backgroundColor: Color.alphaBlend(
              AppColors.warning.withValues(alpha: 0.14),
              scheme.surface,
            ),
            contentTextStyle: TextStyle(color: scheme.onSurface),
            actions: [
              TextButton(
                onPressed: () {},
                child: Text(
                  context.tr('Dismiss'),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
