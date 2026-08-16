import 'package:flutter/material.dart';
import 'package:sso_admin/screens/admin/admin_gate.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// 管理控制面入口 — 独立 deferred chunk（本库体积最大：33 个管理模块）。
/// 入口级 ErrorBoundary：覆盖 AuthGate 与 Dashboard 壳层（导航栏/标题栏），
/// 壳层内每个模块页/详情页另由 dashboard_page_resolution 提供页面级边界。
Widget buildAdminGateScreen() => const ErrorBoundary(child: AdminGateScreen());
