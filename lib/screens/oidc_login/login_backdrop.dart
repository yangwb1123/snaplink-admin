import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 登录页装饰性背景（Apple 式弥散光晕，login-redesign §1）。
///
/// 纯装饰：不拦截指针（IgnorePointer）、显式排除语义（ExcludeSemantics，
/// a11y R3）、无模糊/Ticker/Timer/资产/依赖。4 个静态 [RadialGradient]
/// 光斑（480/560/340/440px）替换原 CustomPainter 几何场景；中央排除带
/// 保留为 [ambientSafeHalfWidth] 放置规则——光斑中心远离中央带，520px
/// 登录卡保持视觉焦点（无需 clip）。光斑按 [Brightness] 切换透明度
/// （暗色 0.06–0.14，亮色 0.08–0.30），颜色同族（indigo-400 / blue-400 /
/// violet-600），主题切换时廉价重建。
class LoginBackdrop extends StatelessWidget {
  final Brightness brightness;

  const LoginBackdrop({super.key, required this.brightness});

  /// 中央排除带半宽：登录卡（520px，半宽 260）外留呼吸空间的光斑放置
  /// 规则——光斑中心尽量落在带外，卡片区域保持干净（不再 clip）。
  static const double ambientSafeHalfWidth = 310;

  /// 光斑直径（px）。
  static const double glowTopLeft = 480;
  static const double glowTopRight = 560;
  static const double glowBottomLeft = 340;
  static const double glowBottomRight = 440;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _glow(
              size: glowTopLeft,
              color: AppColors.primaryOnDark, // indigo-400
              alpha: brightness == Brightness.dark ? 0.14 : 0.30,
              alignment: const Alignment(-0.55, -0.75),
            ),
            _glow(
              size: glowTopRight,
              color: AppColors.accentBlueBright, // blue-400
              alpha: brightness == Brightness.dark ? 0.10 : 0.22,
              alignment: const Alignment(0.65, -0.70),
            ),
            _glow(
              size: glowBottomLeft,
              color: AppColors.violet, // violet-600
              alpha: brightness == Brightness.dark ? 0.08 : 0.16,
              alignment: const Alignment(-0.75, 0.85),
            ),
            _glow(
              size: glowBottomRight,
              color: AppColors.primaryOnDark, // indigo-400
              alpha: brightness == Brightness.dark ? 0.06 : 0.08,
              alignment: const Alignment(0.70, 0.90),
            ),
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
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}
