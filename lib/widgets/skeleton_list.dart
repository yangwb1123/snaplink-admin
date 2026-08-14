import 'package:flutter/material.dart';

/// Skeleton loading placeholder for list items.
/// Shows animated grey rectangles while content is loading.
class SkeletonListTile extends StatefulWidget {
  final int itemCount;
  final bool crossAxis;

  const SkeletonListTile({
    super.key,
    this.itemCount = 5,
    this.crossAxis = false,
  });

  @override
  State<SkeletonListTile> createState() => _SkeletonListTileState();
}

class _SkeletonListTileState extends State<SkeletonListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.crossAxis) {
      return _buildGrid();
    }
    return _buildList();
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
    itemBuilder: (_, _) => _buildItem(),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 200,
                      decoration: BoxDecoration(
                        color: block(factor: 0.245),
                        borderRadius: BorderRadius.circular(4),
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
}
