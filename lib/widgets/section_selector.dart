import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Reusable horizontal section selector chip bar.
class SectionSelector extends StatelessWidget {
  /// 区块定义列表（图标 + 文案键）。
  final List<SectionDef> sections;

  /// 当前选中区块 id。
  final String current;

  /// 选中回调（参数为区块 id）。
  final void Function(String section) onSelected;

  const SectionSelector({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    // SingleChildScrollView（非懒构建）：所有 chips 始终在树中，
    // 视口外可横向滚动到达（AppBar title 等窄容器中不被懒构建裁剪）。
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            // 约束 chip 外层宽度：chip 自身的 Material padding 也会占宽，
            // 只约束 label 里的 Text 不够——chip 整体不得超过 maxWidth，
            // 文字在 chip 内用 Flexible + ellipsis 截断（不超出 chip）。
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 16, color: s.color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr(s.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                selected: current == s.id,
                onSelected: (_) => onSelected(s.id),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Definition for a section in [SectionSelector].
class SectionDef {
  /// 区块唯一标识（选中态与回调入参）。
  final String id;

  /// 区块文案（i18n 键）。
  final String label;

  /// 区块图标。
  final IconData icon;

  /// 图标彩色（品牌强调色）；null 时使用默认前景色。
  final Color? color;

  const SectionDef(this.id, this.label, this.icon, {this.color});

  // destructure for convenience
  String get $1 => id;
  String get $2 => label;
  IconData get $3 => icon;
}
