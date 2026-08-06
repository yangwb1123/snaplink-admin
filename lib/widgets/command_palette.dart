import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
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

  const CommandPalette({
    super.key,
    required this.currentModule,
    required this.allModules,
  });

  /// Show the command palette as a dialog.
  static Future<void> show(
    BuildContext context, {
    required String currentModule,
    required List<String> allModules,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          CommandPalette(currentModule: currentModule, allModules: allModules),
    );
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
                itemBuilder: (_, i) {
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
                    leading: Icon(cmd.icon, size: 20),
                    title: LocalizedText(
                      cmd.title,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      cmd.path,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    dense: true,
                    onTap: () {
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
                      AdminRoute.go(
                        cmd.routeModule,
                        resourceId: cmd.routeId,
                        action: cmd.routeAction,
                        subresource: cmd.routeSubresource,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: LocalizedText(
                'Type to search · ${_results.length} commands',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
