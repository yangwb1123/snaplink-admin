import 'package:flutter/material.dart';

/// 列表页批量选择逻辑（长按进入选择 → 点击切换 → 批量栏）。
/// 三个列表页（clients/tenants/local_users）此前各自内联同一模式——
/// 第三次重复时提取（rule of three）。
mixin BatchSelection<T extends StatefulWidget> on State<T> {
  final Set<String> _selected = {};

  Set<String> get selected => _selected;
  bool get selecting => _selected.isNotEmpty;

  void toggleSelect(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void clearSelection() => setState(_selected.clear);

  /// 列表行点击：选择模式切换选择，否则执行默认动作。
  VoidCallback? rowTap(String id, VoidCallback defaultAction) =>
      selecting ? () => toggleSelect(id) : defaultAction;
}
