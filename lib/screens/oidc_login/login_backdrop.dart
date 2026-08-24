import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 登录页装饰性背景（构图收敛）：单一、静态的柔和光效系统。
///
/// 纯装饰：不拦截指针（IgnorePointer）、显式排除语义（ExcludeSemantics），
/// 无模糊/Ticker/Timer/资产/依赖。主光斑只为卡片提供极弱的背光，四角
/// 光斑保留空气感，底部渐隐负责收束；没有第二套全屏光源。
class LoginBackdrop extends StatelessWidget {
  final Brightness brightness;

  const LoginBackdrop({super.key, required this.brightness});

  /// 中央排除带半宽：登录卡（520px，半宽 260）外留呼吸空间的光斑放置
  /// 规则——除主光斑（故意入带为玻璃卡供光）外，光斑中心尽量落在带外。
  static const double ambientSafeHalfWidth = 310;

  /// 光斑直径（px）。
  static const double glowMain = 900;
  static const double glowTopLeft = 480;
  static const double glowTopRight = 560;
  static const double glowBottomLeft = 340;
  static const double glowBottomRight = 440;

  bool get _light => brightness == Brightness.light;

  /// 按亮度换色（装饰三原则）：暗色保持 400/600 级原色，亮色更浅色阶
  /// （indigo-200 = primaryTint / violet-200 = violetTint）。
  Color _tint(Color darkColor, Color lightColor) =>
      _light ? lightColor : darkColor;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 主光斑打底：中央偏上，暗 0.04 / 亮 0.14，为玻璃卡供光。
            _glow(
              size: glowMain,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.14 : 0.04,
              alignment: const Alignment(0, -0.12),
            ),
            // 四角环境光：低于卡片与主 CTA 的视觉权重。
            _glow(
              size: glowTopLeft,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.16 : 0.08,
              alignment: const Alignment(-0.55, -0.75),
            ),
            _glow(
              size: glowTopRight,
              color: _tint(
                AppColors.accentBlueBright,
                AppColors.accentBlueBright,
              ),
              alpha: _light ? 0.12 : 0.06,
              alignment: const Alignment(0.65, -0.70),
            ),
            _glow(
              size: glowBottomLeft,
              color: _tint(AppColors.violet, AppColors.violetTint),
              alpha: _light ? 0.08 : 0.04,
              alignment: const Alignment(-0.75, 0.85),
            ),
            _glow(
              size: glowBottomRight,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.06 : 0.03,
              alignment: const Alignment(0.70, 0.90),
            ),
            // 底部渐隐收尾：压住底缘光斑，但不形成黑色横带。
            _bottomFade(),
          ],
        ),
      ),
    ),
  );

  /// 单个光斑：大半径径向渐变圆，边缘透明（Apple 式氛围光，无硬边）。
  Widget _glow({
    required double size,
    required Color color,
    required double alpha,
    required Alignment alignment,
  }) => Align(
    alignment: alignment,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );

  /// 底部渐隐：透明 → textStrong（暗 0.32/亮 0.06）收尾，仅装饰。
  Widget _bottomFade() => Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.textStrong.withValues(alpha: 0),
            AppColors.textStrong.withValues(alpha: _light ? 0.06 : 0.32),
          ],
        ),
      ),
    ),
  );
}
