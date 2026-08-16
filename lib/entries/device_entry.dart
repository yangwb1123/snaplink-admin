import 'package:flutter/material.dart';
import 'package:sso_admin/screens/device/device_verify_screen.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// RFC 8628 设备码确认入口 — 独立 deferred chunk。
/// 入口级 ErrorBoundary：验证/审批流程构建崩溃 → 兜底 UI + 重载。
Widget buildDeviceVerifyScreen(Uri routeUri) =>
    ErrorBoundary(child: DeviceVerifyScreen(routeUri: routeUri));
