import 'package:flutter/material.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// 托管登录入口 — 独立 deferred chunk。
/// 入口级 ErrorBoundary：登录/授权/MFA 视图构建崩溃 → 兜底 UI + 重载。
Widget buildLoginScreen({
  String? defaultClientId,
  OidcLoginApi? api,
  required Uri routeUri,
}) => ErrorBoundary(
  child: OidcLoginScreen(
    defaultClientId: defaultClientId,
    api: api,
    routeUri: routeUri,
  ),
);
