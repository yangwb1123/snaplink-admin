import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/widgets/command_palette_commands.dart';

/// Command palette for quick resource search and navigation.
///
/// Triggered by Ctrl+K (or Cmd+K on Mac). Shows a search dialog
/// where the admin can type to find and navigate to any module,
/// detail page, or action.
///
/// This is a client-side only feature — no API call needed.
class CommandPalette extends StatefulWidget {
  final String currentModule;
  final List<String> allModules;

  /// 刷新回调（对应 Ctrl+R 与面板 'Refresh current view' 命令）；由管理
  /// 壳层注入，null 时该命令仅关闭面板。
  final VoidCallback? onRefresh;

  const CommandPalette({
    super.key,
    required this.currentModule,
    required this.allModules,
    this.onRefresh,
  });

  /// 已打开标记：防止 Ctrl/Cmd+K 连按在已打开的面板上再压入一层对话框。
  static bool _isOpen = false;

  /// Show the command palette as a dialog.
  static Future<void> show(
    BuildContext context, {
    required String currentModule,
    required List<String> allModules,
    VoidCallback? onRefresh,
  }) {
    if (_isOpen) return Future.value();
    _isOpen = true;
    return showDialog(
      context: context,
      builder: (_) => CommandPalette(
        currentModule: currentModule,
        allModules: allModules,
        onRefresh: onRefresh,
      ),
    ).whenComplete(() => _isOpen = false);
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<CommandPaletteItem> _results = [];

  @override
  void initState() {
    super.initState();
    _results = _commandsForAvailableModules();
    _focusNode.requestFocus();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final available = _commandsForAvailableModules();
    setState(() {
      if (query.isEmpty) {
        _results = available;
      } else {
        _results = available
            .where(
              (cmd) =>
                  cmd.title.toLowerCase().contains(query) ||
                  context.tr(cmd.title).toLowerCase().contains(query) ||
                  cmd.description.toLowerCase().contains(query) ||
                  cmd.path.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  List<CommandPaletteItem> _commandsForAvailableModules() =>
      commandPaletteItemsForModules(widget.allModules);

  Widget _resultTile(int i) {
    final cmd = _results[i];
    // 组标题（仅浏览态显示；搜索态隐藏避免干扰结果）。
    if (cmd.isGroupHeader && _searchCtrl.text.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          cmd.title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListTile(
      leading: Icon(cmd.icon, size: 20, color: _commandIconColor(cmd)),
      title: LocalizedText(
        cmd.title,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        cmd.path,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      dense: true,
      onTap: () => _activate(cmd),
    );
  }

  /// 命令图标颜色：admin 命令继承所属导航组色（与 rail/子菜单同色系）；
  /// 全局命令（设置/刷新）保持中性主题色，不冒充任何组。
  Color _commandIconColor(CommandPaletteItem cmd) {
    if (!cmd.path.startsWith('/admin/')) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return adminModuleIconColorFor(
      cmd.routeModule,
      Theme.of(context).brightness,
    );
  }

  void _activate(CommandPaletteItem cmd) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (cmd.path == '/settings') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
      return;
    }
    if (cmd.path == '/refresh') {
      // 与 Ctrl+R 同一回调：壳层刷新能力/数据，行为保持一致。
      widget.onRefresh?.call();
      return;
    }
    AdminRoute.go(
      cmd.routeModule,
      resourceId: cmd.routeId,
      action: cmd.routeAction,
      subresource: cmd.routeSubresource,
    );
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search commands...'.localized,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) => _resultTile(i),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: LocalizedText(
                'Type to search · ${_results.length} commands',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
