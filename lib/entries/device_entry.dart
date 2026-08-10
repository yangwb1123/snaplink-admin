import 'package:flutter/material.dart';
import 'package:sso_admin/screens/device/device_verify_screen.dart';

/// RFC 8628 设备码确认入口 — 独立 deferred chunk。
Widget buildDeviceVerifyScreen(Uri routeUri) =>
    DeviceVerifyScreen(routeUri: routeUri);
