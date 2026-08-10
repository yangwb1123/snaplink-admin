import 'package:flutter/material.dart';
import 'package:sso_admin/screens/portal/portal_screen.dart';

/// 用户自助门户入口 — 独立 deferred chunk。
Widget buildPortalScreen(Uri routeUri) => PortalScreen(routeUri: routeUri);
