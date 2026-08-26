part of 'dashboard_screen.dart';

extension _DashboardScreenNavigationView on _DashboardScreenState {
  void _initShortcutsNavigation() {
    ShortcutService().init(
      onCreate: () {
        final module =
            _selectedModule.isNotEmpty &&
                _visibleModules.contains(_selectedModule)
            ? _selectedModule
            : _visibleModules.firstWhere(
                (candidate) => candidate.isNotEmpty,
                orElse: () => AdminModuleId.overview,
              );
        if (module.isNotEmpty) {
          AdminRoute.go(module, action: 'new');
        }
      },
      onRefresh: () {
        _refreshCapabilities();
      },
      // Ctrl+F：聚焦当前列表页搜索框（SearchFilterBar 静态登记）。
      onSearch: () => SearchFilterBar.focusActiveSearch(),
      // Ctrl+1-9：当前分组内模块 chip 顺序切换（与 SectionSelector 一致）。
      onNavigate: _switchModuleByNumber,
      onEscape: () => Navigator.of(context).maybePop(),
      onCommandPalette: () => CommandPalette.show(
        context,
        currentModule: _visibleModules.contains(_selectedModule)
            ? _selectedModule
            : AdminModuleId.overview,
        allModules: _visibleModules
            .where((module) => module.isNotEmpty)
            .toList(growable: false),
        onRefresh: _refreshCapabilities,
      ),
      onShowShortcuts: () => ShortcutsDialog.show(context),
    );
  }

  void _localLogoutNavigation() {
    widget.client.logout();
    Session.clear();
    BrowserNavigation.assignLocation('/login/');
  }

  /// Ctrl+1-9 处理器：按当前分组可见模块顺序切换（与页面 chip 一致）。
  /// 分组推导与 build 保持同一规则，索引越界或同模块时静默返回。
  void _switchModuleByNumberNavigation(int index) {
    if (index < 1) return;
    final visibleGroups = [
      for (final group in adminModuleGroups)
        if (adminGroupVisibleModules(group, _visibleModules).isNotEmpty) group,
    ];
    if (visibleGroups.isEmpty) return;
    final currentGroupId = adminGroupForModule(_selectedModule);
    var groupIndex = visibleGroups.indexWhere((g) => g.id == currentGroupId);
    if (groupIndex < 0) groupIndex = 0;
    final modules = adminGroupVisibleModules(
      visibleGroups[groupIndex],
      _visibleModules,
    );
    if (index > modules.length) return;
    final module = modules[index - 1];
    if (module == _selectedModule) return;
    if (_currentRoute == AdminRoute(module: module)) return;
    _groupLastModule[currentGroupId] = module;
    AdminRoute.go(module);
  }
}
