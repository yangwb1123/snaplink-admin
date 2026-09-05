import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Reusable search and filter bar for list pages.
/// Supports text search, filter chips, and sort selection.
class SearchFilterBar extends StatefulWidget {
  final String hintText;

  /// 有值时优先渲染为 `TextField(labelText:)`（labelText 优先于 hintText）。
  final String? labelText;

  /// 外部控制器注入（内部仍拥有文本）；未提供时内部自建。
  final TextEditingController? controller;

  /// false 时 `onSearchChanged` 同步触发（无 Timer）。
  final bool debounce;

  final List<String> filterOptions;

  /// Filter labels are source copy by default. Set false when options are
  /// API/resource values (for example provider names) and must remain raw.
  final bool translateFilterOptions;

  final String? selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?>? onFilterChanged;
  final VoidCallback? onRefresh;

  /// 键盘 done 提交：同步触发本回调，随后照常走 [onSearchChanged]。
  final ValueChanged<String>? onSubmitted;

  const SearchFilterBar({
    super.key,
    this.hintText = 'Search...',
    this.labelText,
    this.controller,
    this.debounce = true,
    this.filterOptions = const [],
    this.translateFilterOptions = true,
    this.selectedFilter,
    required this.onSearchChanged,
    this.onFilterChanged,
    this.onRefresh,
    this.onSubmitted,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();

  /// 聚焦当前可见的搜索框（全局 Ctrl+F 快捷键入口，无副作用）。
  static void focusActiveSearch() {
    final node = _SearchFilterBarState._activeSearchFocus;
    // context 为空 = 节点已 detach，跳过避免请求悬空焦点。
    if (node == null || node.context == null) return;
    node.requestFocus();
  }
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late TextEditingController _searchCtrl;
  bool _ownsController = false;

  /// 最近一次挂载的搜索框焦点（全局 Ctrl+F 快捷键定位用）。
  /// 页面同一时刻只渲染一个列表页 → 静态单例足够；dispose 时若仍指向
  /// 本节点则清空，避免悬空节点被 requestFocus。
  static FocusNode? _activeSearchFocus;
  final FocusNode _searchFocusNode = FocusNode();
  bool _showFilters = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    _activeSearchFocus = _searchFocusNode;
  }

  void _attachController(TextEditingController? controller) {
    _searchCtrl = controller ?? TextEditingController();
    _ownsController = controller == null;
    _searchCtrl.addListener(_onControllerChanged);
  }

  void _detachController() {
    _searchCtrl.removeListener(_onControllerChanged);
    if (_ownsController) _searchCtrl.dispose();
  }

  void _onControllerChanged() {
    // External controllers can be changed by the page (for example when a
    // filter is cleared outside this widget). Rebuild only the clear affordance
    // here; the page still owns the decision to submit the new value.
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _cancelDebounce();
      _detachController();
      _attachController(widget.controller);
    }
    if (oldWidget.debounce && !widget.debounce) _cancelDebounce();
  }

  @override
  void dispose() {
    if (identical(_activeSearchFocus, _searchFocusNode)) {
      _activeSearchFocus = null;
    }
    _searchFocusNode.dispose();
    _cancelDebounce();
    _detachController();
    super.dispose();
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _onSearchChanged(String value) {
    // 清除按钮可见性跟随文本即时更新（不等待防抖窗口）。
    setState(() {});
    if (!widget.debounce) {
      _cancelDebounce();
      widget.onSearchChanged(value);
      return;
    }
    _cancelDebounce();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _debounceTimer = null;
      if (!mounted || _searchCtrl.text != value) return;
      widget.onSearchChanged(value);
    });
  }

  /// 清除按钮：取消挂起防抖 → 清空文本 → 同步提交空查询（与 Enter 提交
  /// 同语义，见 [onSubmitted]），随后把焦点还给搜索框便于继续输入。
  void _clearSearch() {
    _cancelDebounce();
    _searchCtrl.clear();
    widget.onSearchChanged('');
    widget.onSubmitted?.call('');
    if (mounted) _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.labelText == null
                        ? null
                        : context.tr(widget.labelText!),
                    hintText: widget.labelText == null
                        ? context.tr(widget.hintText)
                        : null,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: context.tr('Clear filter'),
                            onPressed: _clearSearch,
                            // Keep the icon visually compact but retain the
                            // platform minimum hit area for keyboard/touch.
                            constraints: const BoxConstraints(
                              minWidth: kMinInteractiveDimension,
                              minHeight: kMinInteractiveDimension,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.standard,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    // Enter is an explicit submit: do not let the keystroke's
                    // pending debounce fire a second, identical search.
                    _cancelDebounce();
                    widget.onSubmitted?.call(value);
                    widget.onSearchChanged(value);
                  },
                ),
              ),
              if (widget.filterOptions.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_list_off : Icons.filter_list,
                    size: 20,
                  ),
                  tooltip: context.tr('Toggle filters'),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
              ],
              if (widget.onRefresh != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: context.strings.refresh,
                  onPressed: widget.onRefresh,
                ),
              ],
            ],
          ),
          if (_showFilters && widget.filterOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in widget.filterOptions)
                  FilterChip(
                    label: Text(
                      widget.translateFilterOptions
                          ? context.tr(option)
                          : option,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: widget.selectedFilter == option,
                    onSelected: (_) => widget.onFilterChanged?.call(
                      widget.selectedFilter == option ? null : option,
                    ),
                    // Keep a padded semantic/touch target even though the
                    // label itself remains compact.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
