import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/screens/agent/agent_compute_placement.dart';
import 'agent_placement_test.dart'
    show placementApi, placementData, placementDevice, placementResponse;

void main() {
  test(
    'observation time uses local display with bounded DateTime fallback',
    () {
      final date = DateTime.fromMillisecondsSinceEpoch(
        1789574400250,
        isUtc: true,
      );
      expect(
        placementObservationTime(1789574400.25),
        date.toLocal().toString().split('.').first,
      );
      expect(placementObservationTime(0), isNotNull);
      for (final value in [
        1e100,
        double.maxFinite,
        double.infinity,
        double.nan,
        -1,
      ]) {
        expect(placementObservationTime(value), isNull);
      }
    },
  );

  test(
    'explicit next replaces page and refresh returns to first page',
    () async {
      final reads = <http.Request>[];
      final api = placementApi((request) async {
        reads.add(request);
        final next = request.url.queryParameters['after'] != null;
        return placementResponse(
          placementData(
            devices: [placementDevice(next ? 'b' : 'a')],
            cursor: next ? '' : 'a',
          ),
        );
      });
      final model = AgentComputePlacement(
        api: api,
        taskId: 'task-1',
        isCurrent: () => true,
      );
      addTearDown(api.close);
      addTearDown(model.dispose);
      await model.load();
      expect(reads, hasLength(1));
      await model.load(next: true);
      expect(model.page!.devices.single.deviceId, 'b');
      expect(reads.last.url.queryParameters['after'], 'a');
      await model.load(next: true);
      expect(reads, hasLength(2));
      await model.load();
      expect(reads.last.url.queryParameters.containsKey('after'), isFalse);
      expect(model.page!.devices.single.deviceId, 'a');
    },
  );
  for (final late in ['success', 'forbidden', 'unauthorized', 'network']) {
    test(
      'identity/selection change discards late $late and old page',
      () async {
        var current = true;
        final pending = Completer<http.Response>();
        var reads = 0;
        final api = placementApi(
          (_) async => ++reads == 1
              ? placementResponse(placementData(cursor: 'device-a'))
              : pending.future,
        );
        final model = AgentComputePlacement(
          api: api,
          taskId: 'task-1',
          isCurrent: () => current,
        );
        addTearDown(api.close);
        addTearDown(model.dispose);
        await model.load();
        final loading = model.load(next: true);
        await Future<void>.delayed(Duration.zero);
        current = false;
        model.checkContext();
        expect(model.page, isNull);
        expect(model.invalidated, isTrue);
        if (late == 'network') {
          pending.completeError(http.ClientException('private'));
        } else {
          pending.complete(
            placementResponse(
              placementData(),
              status: late == 'success'
                  ? 200
                  : late == 'forbidden'
                  ? 403
                  : 401,
            ),
          );
        }
        await loading;
        expect(model.page, isNull);
        expect(model.error, contains('sign-in or selected session changed'));
        await model.load();
        expect(reads, 2);
      },
    );
  }
  for (final status in [401, 403, 404, 405, 501, 500]) {
    test(
      '$status clears current page and cursor and offers safe refresh',
      () async {
        var reads = 0;
        final api = placementApi(
          (_) async => ++reads == 1
              ? placementResponse(placementData(cursor: 'device-a'))
              : http.Response('private credential/path', status),
        );
        final model = AgentComputePlacement(
          api: api,
          taskId: 'task-1',
          isCurrent: () => true,
        );
        addTearDown(api.close);
        addTearDown(model.dispose);
        await model.load();
        await model.load(next: true);
        expect(model.page, isNull);
        expect(model.busy, isFalse);
        expect(model.error, isNot(contains('private')));
        expect(
          model.error,
          contains(
            status == 401 || status == 403
                ? 'permission'
                : [404, 405, 501].contains(status)
                ? 'does not support'
                : 'Could not inspect',
          ),
        );
        await model.load(next: true);
        expect(reads, 2);
      },
    );
  }
  test(
    'busy actions do not duplicate reads and disposed controller drops result',
    () async {
      final pending = Completer<http.Response>();
      var reads = 0;
      final api = placementApi((_) {
        reads++;
        return pending.future;
      });
      final model = AgentComputePlacement(
        api: api,
        taskId: 'task-1',
        isCurrent: () => true,
      );
      addTearDown(api.close);
      final read = model.load();
      await model.load();
      await model.load(next: true);
      model.dispose();
      pending.complete(placementResponse(placementData()));
      await read;
      expect(reads, 1);
      expect(model.page, isNull);
    },
  );
}
