import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';

/// 租户筛选行：搜索 + 状态筛选 + 排序 + 每页条数（纯受控组件）。
///
/// 从 tenants_tab 拆出：状态（控制器/筛选值/排序/条数）与刷新回调由页面
/// 持有，本组件只负责渲染与回调转发，保持原 API 契约与 i18n 语义不变。
class TenantsFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String statusFilter;
  final String orderBy;
  final int pageSize;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onOrderChanged;
  final ValueChanged<int> onPageSizeChanged;

  const TenantsFilterBar({
    super.key,
    required this.controller,
    required this.statusFilter,
    required this.orderBy,
    required this.pageSize,
    required this.onSearchSubmitted,
    required this.onStatusChanged,
    required this.onOrderChanged,
    required this.onPageSizeChanged,
  });

  static const _orderOptions = [
    ('id', 'ID ascending'),
    ('-id', 'ID descending'),
    ('slug', 'Slug ascending'),
    ('-slug', 'Slug descending'),
    ('name', 'Name ascending'),
    ('-name', 'Name descending'),
  ];
  static const _sizeOptions = [
    (25, '25 per page'),
    (100, '100 per page'),
    (250, '250 per page'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: SearchFilterBar(
              labelText: 'Filter'.localized,
              controller: controller,
              debounce: false,
              onSearchChanged: (_) {},
              onSubmitted: (_) => onSearchSubmitted(),
            ),
          ),
          const SizedBox(width: 12),
          StatusFilterDropdown(
            value: statusFilter,
            options: const {
              'all': 'All statuses',
              'active': 'Active only',
              'suspended': 'Suspended only',
            },
            onChanged: onStatusChanged,
          ),
          DropdownButton<String>(
            value: orderBy,
            items: [
              for (final (value, label) in _orderOptions)
                DropdownMenuItem(value: value, child: LocalizedText(label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              onOrderChanged(value);
            },
          ),
          DropdownButton<int>(
            value: pageSize,
            items: [
              for (final (size, label) in _sizeOptions)
                DropdownMenuItem(value: size, child: LocalizedText(label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              onPageSizeChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
