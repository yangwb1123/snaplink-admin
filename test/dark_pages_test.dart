import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/screens/portal/overview_tab.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/theme/app_theme.dart';
import 'package:sso_admin/widgets/status_chip.dart';

/// 深色模式页面 smoke：关键页面在 dark 主题下渲染无异常/无溢出。
///
/// StatusChip 的对比度由 dark_mode_test 守护；这里覆盖页面级集成——
/// 页面在 dark 下抛异常或溢出会在此失败。
MockClient _client(Map<String, http.Response Function(http.Request)> routes) =>
    MockClient((request) async {
      final response = routes[request.url.path];
      if (response != null) return response(request);
      return http.Response('{"error":"not found"}', 404);
    });

Widget _darkWrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  group('dark pages smoke', () {
    testWidgets('settings screen renders under dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const SettingsScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
      // 分组卡片标题渲染（第一张卡片在视口内）
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('portal overview renders under dark theme', (tester) async {
      final api = PortalApi(
        httpClient: _client({
          '/me': (_) => http.Response(
            jsonEncode({
              'user': {
                'sub': 'user-1',
                'name': 'Ada',
                'email': 'ada@example.test',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
          '/me/attributes': (_) =>
              http.Response('[]', 200, headers: {'content-type': 'application/json'}),
        }),
        baseUri: Uri.parse('https://sso.example.test'),
      );
      await tester.pumpWidget(_darkWrap(OverviewTab(api: api)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Ada'), findsWidgets);
    });

    testWidgets('pagination + status chips render under dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Column(
              children: [
                StatusChip.active(),
                StatusChip.inactive(),
                StatusChip.suspended(),
                StatusChip.healthy(),
                StatusChip.unhealthy(),
                _DarkProbe(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _DarkProbe extends StatelessWidget {
  const _DarkProbe();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Dark surface probe',
        style: TextStyle(color: scheme.onSurface),
      ),
    );
  }
}
