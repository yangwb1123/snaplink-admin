/// 应用颜色常量（从散落的硬编码色值集中提取，AI 规范门禁驱动）。
/// 替代各处散落的 `Color(0xFF...)` 字面量：单点定义、可主题化、可审计。
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  /// 主品牌色（indigo）
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF3730A3);

  /// 文字与背景（slate 系）
  static const Color textStrong = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF1E293B);
  static const Color textSubtle = Color(0xFF334155);

  /// 品牌蓝（通用强调）
  static const Color accentBlue = Color(0xFF2563EB);

  /// 成功（emerald 系）
  static const Color success = Color(0xFF059669);
  static const Color successDark = Color(0xFF064E3B);
  static const Color successTint = Color(0xFFA7F3D0);

  /// 危险（red 系）
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerDark = Color(0xFF7F1D1D);
  static const Color dangerTint = Color(0xFFFECACA);

  /// 警告（amber）
  static const Color warning = Color(0xFFD97706);

  /// 中性灰（inactive 等）——slate-500：对白底点缀对比 ≥3（WCAG 非文本）
  static const Color muted = Color(0xFF64748B);
  /// 头像/标签辅助色（UserAvatar 调色板）
  static const Color violet = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF0891B2);
  static const Color pink = Color(0xFFDB2777);
  /// 辅助（indigo 淡色）
  static const Color primaryTint = Color(0xFFC7D2FE);

  /// 导航组图标色板（admin_module_groups 一级导航 / 设置页品牌色同族）。
  /// 单点定义：组 map、组 const 列表与设置页图标共用，避免同色值三处手写。
  static const Color groupOverview = Color(0xFF0EA5E9); // sky
  static const Color groupIdentity = Color(0xFF7C6FF0); // indigo-violet
  static const Color groupSecurity = Color(0xFFF43F5E); // rose
  static const Color groupTenants = Color(0xFFF59E0B); // amber
  static const Color groupDevelopers = Color(0xFF10B981); // emerald
  static const Color groupSystem = Color(0xFF4F46E5); // indigo

  /// System 组图标色 dark 提亮变体（indigo-400）：indigo-600 对深色
  /// surface 仅 2.33:1（WCAG 非文本 <3），dark 下经
  /// `adminGroupIconColorFor` 切换为本色（4.90:1）。浅色保持 indigo-600
  /// （对白底 6.3:1）。
  static const Color groupSystemDark = Color(0xFF818CF8);

  /// 主题模式图标强调色（theme_selector；品牌强调色，刻意不随 colorScheme
  /// 派生）。浅/深界面各一套，值按既有视觉保持不变。
  static const Color themeSystemAccent = Color(0xFF7C6FF0); // = groupIdentity
  static const Color themeLightAccent = Color(0xFFB45309); // amber-700
  static const Color themeDarkAccent = Color(0xFF4F46E5); // = groupSystem
  static const Color themeLightAccentBright = Color(0xFFF59E0B); // = groupTenants
  static const Color themeDarkAccentBright = Color(0xFF818CF8); // indigo-400

  /// 浅色脚手架背景（品牌浅灰，区别于纯白模板）。
  static const Color surfaceSubtle = Color(0xFFF5F7FA);
}
