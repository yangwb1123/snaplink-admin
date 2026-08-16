import 'package:flutter/material.dart';
import 'package:sso_admin/screens/setup/setup_screen.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// 首次初始化入口 — 独立 deferred chunk。
///
/// app_router.dart 以 `deferred as` 引用本文件，`loadLibrary()` 完成前
/// 本库的代码不会进入主 bundle，因此 /setup/ 只在被访问时才下载。
/// 入口级 ErrorBoundary：引导向导任一步骤构建崩溃 → 兜底 UI + 重载。
Widget buildSetupScreen() => const ErrorBoundary(child: SetupScreen());
