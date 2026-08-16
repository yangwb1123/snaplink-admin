import 'package:flutter/material.dart';
import 'package:sso_admin/screens/developer/developer_screen.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// 开发者动态注册入口 — 独立 deferred chunk。
/// 入口级 ErrorBoundary：注册/管理双面板整屏兜底（面板内崩溃 → 兜底 UI + 重载）。
Widget buildDeveloperScreen() => const ErrorBoundary(child: DeveloperScreen());
