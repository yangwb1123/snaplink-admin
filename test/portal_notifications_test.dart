import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/notification_bell.dart';
import 'package:sso_admin/screens/portal/notifications_tab.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';

void main() {
  test(
    'notification stream sends bearer and parses multiline SSE data',
    () async {
      late http.BaseRequest streamRequest;
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me') {
            return http.Response('{"sub":"user-1"}', 200);
          }
          streamRequest = request;
          return http.Response(
            'id: event-1\n'
            'event: notification\n'
            'data: {"id":"notification-1",\n'
            'data: "title":"New sign-in"}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      await api.login('portal-token');

      final events = await api
          .notificationEvents(lastEventId: 'event-0')
          .toList();

      expect(events, [
        {'id': 'notification-1', 'title': 'New sign-in'},
      ]);
      expect(streamRequest.url.path, '/me/notifications/stream');
      expect(streamRequest.headers['authorization'], 'Bearer portal-token');
      expect(streamRequest.headers['last-event-id'], 'event-0');
    },
  );

  testWidgets('notification inbox marks read and saves preferences', (
    tester,
  ) async {
    final markedRead = <String>[];
    var changed = 0;
    Map<String, dynamic>? saved;
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me/notifications' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 'notification-1',
                  'title': 'New device sign-in',
                  'body': 'Firefox on Linux',
                  'severity': 'warning',
                  'created_at': '2026-08-01T00:00:00Z',
                  'read_at': null,
                },
                {
                  'id': 'notification-2',
                  'type': 'password_expiring',
                  'title': 'Password expires soon',
                  'body': 'Change your password.',
                  'severity': 'warning',
                  'created_at': '2026-07-31T00:00:00Z',
                  'read_at': null,
                },
              ],
              'unread_count': 2,
              'has_more': false,
            }),
            200,
          );
        }
        if (request.url.path == '/me/notifications/preferences' &&
            request.method == 'GET') {
          return http.Response(
            '{"preferences":[{"type":"new_device_login",'
            '"channel":"email","enabled":true}]}',
            200,
          );
        }
        if (request.url.path.startsWith('/me/notifications/notification-') &&
            request.url.path.endsWith('/read')) {
          markedRead.add(request.url.path);
          return http.Response('{}', 200);
        }
        if (request.url.path == '/me/notifications/preferences' &&
            request.method == 'PUT') {
          saved = jsonDecode(request.body);
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(api: api, onChanged: () => changed++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 unread security and account notifications.'), findsOne);
    await tester.tap(find.text('New device sign-in'));
    await tester.pumpAndSettle();
    expect(markedRead, ['/me/notifications/notification-1/read']);
    expect(changed, 1);
    expect(find.text('1 unread security and account notifications.'), findsOne);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    // 确认对话框（影响数量）→ 确认
    expect(find.textContaining('Mark all as read?'), findsWidgets);
    await tester.tap(find.text('Mark all').last);
    await tester.pumpAndSettle();
    expect(markedRead, [
      '/me/notifications/notification-1/read',
      '/me/notifications/notification-2/read',
    ]);
    expect(changed, 2);
    expect(find.text('0 unread security and account notifications.'), findsOne);

    await tester.tap(find.byType(Switch));
    await tester.scrollUntilVisible(
      find.text('Save preferences'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    final preferences = saved?['preferences'] as List<dynamic>?;
    expect(preferences, hasLength(1));
    expect((preferences!.single as Map<String, dynamic>)['enabled'], isFalse);
    expect(find.text('Notification preferences saved.'), findsOneWidget);
  });

  testWidgets('notification bell shows badge, preview, and opens inbox', (
    tester,
  ) async {
    var opened = false;
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBell(
                unreadCount: 7,
                recent: const [
                  {
                    'id': 'notification-1',
                    'title': 'Password expires soon',
                    'body': 'Change it in the security center.',
                    'read_at': null,
                  },
                ],
                onViewAll: () => opened = true,
                onOpen: (notification) => selected = notification,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Password expires soon'), findsOneWidget);
    await tester.tap(find.text('Password expires soon'));
    await tester.pumpAndSettle();
    expect(selected?['id'], 'notification-1');
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all notifications'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('mark all read cancels without marking', (tester) async {
    final markedRead = <String>[];
    var changed = 0;
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me/notifications' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 'notification-1',
                  'title': 'New device sign-in',
                  'body': 'Firefox on Linux',
                  'severity': 'warning',
                },
              ],
              'unread_count': 1,
              'preferences': {},
            }),
            200,
          );
        }
        if (request.url.path == '/me/notifications/notification-1/read' &&
            request.method == 'POST') {
          markedRead.add('notification-1');
          return http.Response('{}', 200);
        }
        if (request.url.path == '/me/notifications/preferences') {
          return http.Response('{}', 200);
        }
        return http.Response('{"error":"not found"}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsTab(api: api, onChanged: () => changed++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    // 取消确认——不执行任何标记。
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(markedRead, isEmpty);
    expect(changed, 0);
  });
}
