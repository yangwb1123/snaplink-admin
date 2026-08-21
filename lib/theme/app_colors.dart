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

  /// SnackBar 错误图标（浅色模式）：snackbar 底为深色 inverseSurface，
  /// danger-700 对比仅 2.03:1（WCAG 非文本 <3），red-400 达 4.74:1；
  /// 深色模式底为浅色，改用 dangerDark（7.76:1）。见 app_snackbar.dart。
  /// 值 = dangerBright（R29 深色前景提亮变体，两处共用同一红色）。
  static const Color dangerOnInverse = Color(0xFFF87171);

  /// 深色模式语义前景提亮变体（R29 对比度修复）：danger/success/
  /// accentBlue/warning 原色对深色 surface（textMuted）对比不足
  /// （2.26-3.88:1，WCAG 正文 <4.5 / 非文本 <3），dark 下文字与图标用
  /// 400 级亮变体（5.29-8.76:1 ≥AA）；浅色模式恒等于原色（视觉不变）。
  /// 由 [semanticFor] 按亮度选择。
  static const Color dangerBright = Color(0xFFF87171); // red-400
  static const Color successBright = Color(0xFF34D399); // emerald-400
  static const Color accentBlueBright = Color(0xFF60A5FA); // blue-400
  static const Color warningBright = Color(0xFFFBBF24); // amber-400

  /// 深色模式品牌主色（indigo-400，= groupSystemDark）：indigo-600 对深色
  /// surface 仅 3.27:1（正文 <4.5），400 级达 4.90:1。app_theme dark 的
  /// primary 使用本值；浅色恒为 [primary]。
  static const Color primaryOnDark = Color(0xFF818CF8);

  /// 破坏性 OutlinedButton 样式（R32 按钮体系）：前景与边框统一危险色，
  /// dark 下经 [semanticFor] 提亮；避免各处重复手写两段 color/side。
  static ButtonStyle dangerOutlinedStyle(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: semanticFor(Theme.of(context).brightness, danger),
        side: BorderSide(
          color: semanticFor(Theme.of(context).brightness, danger),
        ),
      );

  /// 语义前景亮度感知（R29）：浅色恒等原色；深色返回同族 400 提亮变体
  /// （文字 ≥4.5、非文本 ≥3）。未知颜色（中性/自定义/组色板）原样返回。
  static Color semanticFor(Brightness brightness, Color light) {
    if (brightness == Brightness.light) return light;
    if (light == danger) return dangerBright;
    if (light == success) return successBright;
    if (light == accentBlue) return accentBlueBright;
    if (light == warning) return warningBright;
    if (light == primary) return primaryOnDark;
    return light;
  }

  /// 警告（amber）
  static const Color warning = Color(0xFFD97706);

  /// 中性灰（inactive 等）——slate-500：对白底点缀对比 ≥3（WCAG 非文本）
  static const Color muted = Color(0xFF64748B);

  /// 头像/标签辅助色（UserAvatar 调色板）
  static const Color violet = Color(0xFF7C3AED);

  /// 装饰紫淡色（violet-200，login-redesign-2 极光背景亮色更浅色阶）。
  static const Color violetTint = Color(0xFFDDD6FE);
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
  static const Color themeLightAccentBright = Color(
    0xFFF59E0B,
  ); // = groupTenants
  static const Color themeDarkAccentBright = Color(0xFF818CF8); // indigo-400

  /// 浅色脚手架背景（品牌浅灰，区别于纯白模板）。
  static const Color surfaceSubtle = Color(0xFFF5F7FA);
}
