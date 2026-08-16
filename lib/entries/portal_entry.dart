import 'package:flutter/material.dart';
import 'package:sso_admin/screens/portal/portal_screen.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// 用户自助门户入口 — 独立 deferred chunk。
/// 入口级 ErrorBoundary：TokenGate/壳层整体兜底；壳层内每个 tab 页面
/// 另有页面级边界（portal_screen_shell 的 _buildApp）。
Widget buildPortalScreen(Uri routeUri) =>
    ErrorBoundary(child: PortalScreen(routeUri: routeUri));
