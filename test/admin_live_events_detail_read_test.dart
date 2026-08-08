import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_live_events_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

/// MockClient cannot hold an SSE connection open (its handler completes),
/// which would drive AdminLiveEventsTab into its reconnect loop. This client
/// keeps the stream alive under the tab's control and routes everything else
/// through a recording MockClient.
class _LiveStreamClient extends http.BaseClient {
  final MockClient inner;
  final StreamController<List<int>> streamController;

  _LiveStreamClient(this.inner)
    : streamController = StreamController<List<int>>.broadcast();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/admin/events/stream') {
      return http.StreamedResponse(
        streamController.stream,
        200,
        headers: const {'content-type': 'text/event-stream'},
      );
    }
    return inner.send(request);
  }
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  Future<void> pumpTab(
    WidgetTester tester,
    _LiveStreamClient client,
    List<Uri> requests,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminLiveEventsTab(
            api: SnaplinkAdminApi(
              baseUrl: 'https://sso.example.test',
              accessToken: 'admin-token',
              httpClient: client,
            ),
            endpoints: [
              SnaplinkAdminEndpoint(
                method: 'GET',
                path: '/api/v1/admin/events/stream',
                feature: 'core',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'row tap reads the encoded {id} detail path and renders the dialog',
    (tester) async {
      final requests = <Uri>[];
      final client = _LiveStreamClient(
        MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/api/v1/audit/events/ev%201%2F2') {
            return http.Response(
              jsonEncode({'id': 'ev 1/2', 'type': 'admin_client_created'}),
              200,
            );
          }
          return http.Response('{"error":"not found"}', 404);
        }),
      );
      addTearDown(() async {
        await client.streamController.close();
      });
      await pumpTab(tester, client, requests);

      // Connect and deliver one SSE event whose id needs path encoding.
      await tester.tap(find.text('Connect'));
      await tester.pump();
      client.streamController.add(
        utf8.encode('id: ev 1/2\ndata: {"type":"admin_client_created"}\n\n'),
      );
      await tester.pumpAndSettle();

      expect(find.text('ev 1/2'), findsOneWidget);
      await tester.tap(find.text('ev 1/2'));
      await tester.pumpAndSettle();

      // The {id} trio member: Uri.encodeComponent must be on the wire, so a
      // slash inside the id survives as %2F instead of becoming a path
      // segment separator.
      expect(
        requests.map((url) => url.path),
        contains('/api/v1/audit/events/ev%201%2F2'),
      );
      expect(find.text('Audit event ev 1/2'), findsOneWidget);
      expect(find.text('admin_client_created'), findsOneWidget);
    },
  );
}
