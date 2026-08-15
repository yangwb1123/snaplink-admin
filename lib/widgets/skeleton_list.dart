import 'dart:async';

import 'package:flutter/material.dart';

/// 骨架屏形态：与真实内容形状匹配（列表行 / 指标卡）。
///
/// R19：指标/面板页（MetricStrip、卡片堆叠）应使用 [SkeletonVariant.card]，
/// 避免列表行骨架与真实卡片内容形状不符。
enum SkeletonVariant {
  /// 列表行：图标 + 两行文字（列表/表格页）。
  list,

  /// 指标卡：图标圆角块 + 数值条 + 标签条（指标/面板页）。
  card,
}

/// Skeleton loading placeholder for list items.
/// Shows animated grey rectangles while content is loading.
///
/// 主题化骨架底色（onSurface 低 alpha，深浅色模式自适应）；列表、网格与
/// 指标卡三种形态，均不可滚动（shrinkWrap），置于数据加载区域原位占位。
/// [delay] 用于快速加载防闪：数据 <delay 返回时骨架保持不可见（占位空间
/// 不跳变），超过 delay 才淡入——避免 <200ms 加载的闪屏。
class SkeletonListTile extends StatefulWidget {
  /// 占位条目数量（默认 5）。
  final int itemCount;

  /// true = 3 列网格形态；false = 列表行形态。
  final bool crossAxis;

  /// 占位形状：[SkeletonVariant.list]（行）/[SkeletonVariant.card]（指标卡）。
  final SkeletonVariant variant;

  /// 延迟显示时长（默认零 = 立即显示，行为与旧版一致）。
  final Duration delay;

  const SkeletonListTile({
    super.key,
    this.itemCount = 5,
    this.crossAxis = false,
    this.variant = SkeletonVariant.list,
    this.delay = Duration.zero,
  });

  @override
  State<SkeletonListTile> createState() => _SkeletonListTileState();
}

class _SkeletonListTileState extends State<SkeletonListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) setState(() => _revealed = true);
      });
    } else {
      _revealed = true;
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.crossAxis
        ? _buildGrid()
        : widget.variant == SkeletonVariant.card
        ? _buildCards()
        : _buildList();
    // 快速加载防闪：delay 期间占位但不可见，超时后淡入；数据先到则整个
    // 骨架从未可见，零闪屏且布局不跳变。
    if (widget.delay == Duration.zero) return content;
    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: content,
    );
  }

  Widget _buildList() => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: widget.itemCount,
    itemBuilder: (_, _) => _buildItem(),
  );

  Widget _buildGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
    ),
    itemCount: widget.itemCount,
    itemBuilder: (_, _) => widget.variant == SkeletonVariant.card
        ? _buildCardItem()
        : _buildItem(),
  );

  /// 指标卡形态：图标圆角块 + 数值条 + 标签条 + 说明条，与
  /// [KeyMetricCard]（widgets/key_metric_card.dart）形状对应。
  Widget _buildCards() => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: widget.itemCount,
    itemBuilder: (_, _) => _buildCardItem(),
  );

  Widget _buildItem() {
    final scheme = Theme.of(context).colorScheme;
    // 骨架底色主题化：onSurface 低 alpha（浅/深色模式自适应，替代硬编码 grey）。
    Color block({required double factor}) =>
        scheme.onSurface.withValues(alpha: _animation.value * factor);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: block(factor: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: block(factor: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 200,
                      decoration: BoxDecoration(
                        color: block(factor: 0.245),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem() {
    final scheme = Theme.of(context).colorScheme;
    Color block({required double factor}) =>
        scheme.onSurface.withValues(alpha: _animation.value * factor);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: block(factor: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 52,
                    height: 14,
                    decoration: BoxDecoration(
                      color: block(factor: 0.245),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 110,
                height: 22,
                decoration: BoxDecoration(
                  color: block(factor: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 96,
                height: 10,
                decoration: BoxDecoration(
                  color: block(factor: 0.245),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 150,
                height: 8,
                decoration: BoxDecoration(
                  color: block(factor: 0.245),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
