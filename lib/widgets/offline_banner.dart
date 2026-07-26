import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/services/connectivity_service.dart';

/// Offline banner widget that shows when the browser goes offline.
/// 
/// Place at the top of the widget tree (e.g., in dashboard_screen)
/// to get a non-intrusive "You are offline" message.
class OfflineBanner extends StatefulWidget {
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
    return Column(
      children: [
        if (_offline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            content: const Text('You are offline. Some features may be unavailable.'),
            leading: const Icon(Icons.wifi_off, color: Colors.white),
            backgroundColor: Colors.orange.shade800,
            contentTextStyle: const TextStyle(color: Colors.white),
            actions: [
              TextButton(
                onPressed: () {},
                child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
