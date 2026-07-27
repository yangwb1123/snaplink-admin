import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/command_palette_commands.dart';

void main() {
  group('command palette capability filtering', () {
    test('includes SCIM Directory when the module is available', () {
      final commands = commandPaletteItemsForModules(const ['scim-directory']);

      expect(
        commands,
        contains(
          isA<CommandPaletteItem>()
              .having((item) => item.title, 'title', 'Go to SCIM Directory')
              .having((item) => item.path, 'path', '/admin/scim-directory'),
        ),
      );
    });

    test('excludes SCIM Directory when the module is unavailable', () {
      final commands = commandPaletteItemsForModules(const ['clients']);

      expect(
        commands.where((item) => item.path == '/admin/scim-directory'),
        isEmpty,
      );
      expect(commands.where((item) => item.path == '/settings'), hasLength(1));
    });
  });

  group('command palette route parsing', () {
    test('parses detail, action, and subresource routes', () {
      const detail = CommandPaletteItem(
        'Detail',
        '/admin/users/u-1',
        Icons.circle,
        '',
      );
      const create = CommandPaletteItem(
        'Create',
        '/admin/clients/new',
        Icons.circle,
        '',
      );
      const report = CommandPaletteItem(
        'Report',
        '/admin/credentials/report',
        Icons.circle,
        '',
      );

      expect((detail.routeModule, detail.routeId), ('users', 'u-1'));
      expect(create.routeAction, 'new');
      expect(report.routeSubresource, 'report');
    });
  });
}
