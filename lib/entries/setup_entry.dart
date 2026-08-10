import 'package:flutter/material.dart';
import 'package:sso_admin/screens/setup/setup_screen.dart';

/// 首次初始化入口 — 独立 deferred chunk。
///
/// app_router.dart 以 `deferred as` 引用本文件，`loadLibrary()` 完成前
/// 本库的代码不会进入主 bundle，因此 /setup/ 只在被访问时才下载。
Widget buildSetupScreen() => const SetupScreen();
