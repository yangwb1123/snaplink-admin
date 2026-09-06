import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';
import 'package:sso_admin/screens/portal/security_activity_tab.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';
import 'package:sso_admin/widgets/timeline_list.dart';

Widget _portal(
  Locale locale,
  PortalApi api, {
  TextScaler? textScaler,
  bool disableAnimations = false,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: textScaler,
        disableAnimations: disableAnimations,
      ),
      child: child!,
    );
  },
  home: SecurityActivityTab(api: api),
);

PortalApi _activityApi({
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> history,
}) => PortalApi(
  httpClient: MockClient((request) async {
    if (request.url.path == '/me/security/activity') {
      return http.Response.bytes(
        utf8.encode(jsonEncode({'events': events})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (request.url.path == '/me/login-history') {
      return http.Response.bytes(
        utf8.encode(jsonEncode({'login_history': history})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{}', 404);
  }),
);

void main() {
  testWidgets('optional activity requests fail independently', (tester) async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me/security/activity') {
          return http.Response('{}', 500);
        }
        if (request.url.path == '/me/login-history') {
          return http.Response(
            '{"login_history":[{"id":"login-1","success":true,'
            '"device":"Chrome on macOS"}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SecurityActivityTab(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Could not load security activity.'), findsOneWidget);
    expect(find.text('Successful login'), findsOneWidget);
    expect(find.textContaining('Chrome on macOS'), findsOneWidget);
  });

  testWidgets('security timeline keeps English copy and API values distinct', (
    tester,
  ) async {
    final api = _activityApi(
      events: [
        {
          'type': 'custom_event_v2',
          'detail': 'server detail / opaque-device-7',
          'location': 'Berlin',
          'ip': '203.0.113.7',
          'provider': 'provider-from-server',
        },
        {'type': 'new_device'},
        {'type': 'new_location'},
        {'type': 'device_registered'},
        {'type': 'login'},
      ],
      history: [
        {
          'success': true,
          'device': 'Chrome on macOS',
          'device_is_new': true,
          'location_is_new': true,
        },
        {'success': false, 'device': 'Firefox on Linux'},
      ],
    );

    await tester.pumpWidget(_portal(const Locale('en'), api));
    await tester.pumpAndSettle();

    expect(find.text('New device detected'), findsOneWidget);
    expect(find.text('New location detected'), findsOneWidget);
    expect(find.text('Device registered'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('custom_event_v2'), findsOneWidget);
    expect(
      find.textContaining('server detail / opaque-device-7'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Login history'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.textContaining('new device'), findsOneWidget);
    expect(find.textContaining('new location'), findsOneWidget);
    expect(find.textContaining('Chrome on macOS'), findsOneWidget);
  });

  testWidgets('security timeline translates registered copy in zh only', (
    tester,
  ) async {
    final api = _activityApi(
      events: [
        {'type': 'custom_event_v2', 'detail': '服务器详情-原样'},
        {'type': 'new_device'},
        {'type': 'new_location'},
        {'type': 'device_registered'},
        {'type': 'login'},
      ],
      history: [
        {
          'success': true,
          'device': '设备标识符-原样',
          'device_is_new': true,
          'location_is_new': true,
        },
        {'success': false, 'device': 'Firefox on Linux'},
      ],
    );

    await tester.pumpWidget(_portal(const Locale('zh'), api));
    await tester.pumpAndSettle();
    expect(find.text('检测到新设备'), findsOneWidget);
    expect(find.text('检测到新位置'), findsOneWidget);
    expect(find.text('设备已注册'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('custom_event_v2'), findsOneWidget);
    expect(find.textContaining('服务器详情-原样'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('登录历史'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('— · 设备标识符-原样 · 新设备 · 新位置'), findsOneWidget);
    expect(find.text('登录成功'), findsOneWidget);
    expect(find.text('登录失败'), findsOneWidget);
  });

  testWidgets('security activity stays contained at zh/2x matrix widths', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const longDetail =
        'detail-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    const longLocation =
        'location-yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
    const longIp =
        '203.0.113.12345678901234567890123456789012345678901234567890';
    const longDevice =
        'device-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
    const longProvider =
        'provider-qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';
    final api = _activityApi(
      events: [
        {
          'type': 'new_device',
          'detail': longDetail,
          'location': longLocation,
          'ip': longIp,
          'provider': longProvider,
        },
        {
          'type': 'new_location',
          'detail': longDetail,
          'location': longLocation,
          'ip': longIp,
          'provider': longProvider,
        },
      ],
      history: [
        {
          'success': true,
          'device': longDevice,
          'device_is_new': true,
          'location_is_new': true,
          'provider': longProvider,
        },
      ],
    );

    for (final width in const [240.0, 320.0, 400.0, 640.0, 768.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _portal(
          const Locale('zh'),
          api,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Security Activity overflowed at $width px (zh, 2x)',
      );
      expect(find.text('检测到新设备', skipOffstage: false), findsOneWidget);
      expect(find.text('检测到新位置', skipOffstage: false), findsOneWidget);
      expect(
        find.textContaining(longDetail, skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.textContaining(longLocation, skipOffstage: false),
        findsWidgets,
      );
      expect(find.textContaining(longIp, skipOffstage: false), findsWidgets);
      expect(
        find.textContaining(longDevice, skipOffstage: false),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'timeline semantics, live errors, refresh, and reduced motion stay stable',
    (tester) async {
      final paths = <String>[];
      var responsesFail = true;
      final api = PortalApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me/security/activity') {
            return responsesFail
                ? http.Response('{}', 500)
                : http.Response('{"events":[{"type":"login"}]}', 200);
          }
          if (request.url.path == '/me/login-history') {
            return http.Response(
              '{"login_history":[{"success":true,"device":"device"}]}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        _portal(
          const Locale('zh'),
          api,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('无法加载安全活动。'), findsOneWidget);
      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any((node) => node.properties.liveRegion == true),
        isTrue,
      );
      final timelines = find.byType(TimelineList, skipOffstage: false);
      expect(timelines, findsOneWidget);
      expect(
        tester.getSemantics(timelines).getSemanticsData().role,
        ui.SemanticsRole.list,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == ui.SemanticsRole.listItem,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.byType(StaggeredFadeIn, skipOffstage: false), findsNothing);

      final refresh = find.widgetWithIcon(IconButton, Icons.refresh);
      expect(refresh, findsOneWidget);
      expect(
        paths,
        unorderedEquals(['/me/security/activity', '/me/login-history']),
      );
      responsesFail = false;
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(paths, hasLength(4));
      expect(
        paths.sublist(2),
        unorderedEquals(['/me/security/activity', '/me/login-history']),
      );
      semanticsHandle.dispose();
    },
  );

  testWidgets('Activity tab issues only /me BFF paths — never the audit trio', (
    tester,
  ) async {
    // B6-1 AC-2(b): the portal Activity tab must never call the audit trio
    // (`/api/v1/audit/events|facets|events/{id}`) — the timeline read
    // belongs to SnaplinkAdminApi via AuditReadClient. The recorded path
    // set is the authoritative gate; the `fail()` inside the handler is a
    // fast-fail diagnostic only (the tab's catch-all swallows it into its
    // error banner, so the set assertion below is what actually fails on an
    // audit request).
    final paths = <String>[];
    final api = PortalApi(
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.startsWith('/api/v1/audit')) {
          fail(
            'portal Activity tab must never call the audit trio: '
            '${request.url.path}',
          );
        }
        if (request.url.path == '/me/security/activity') {
          return http.Response('{"events":[]}', 200);
        }
        if (request.url.path == '/me/login-history') {
          return http.Response('{"login_history":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SecurityActivityTab(api: api)));
    await tester.pumpAndSettle();
    expect(
      paths,
      unorderedEquals(['/me/security/activity', '/me/login-history']),
    );
  });
}
