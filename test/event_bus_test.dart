import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/event_bus.dart';

void main() {
  group('EventBus', () {
    test('fires and listens for events', () {
      final bus = EventBus();
      String? received;
      bus.on<String>().listen((e) => received = e);
      bus.fire('hello');
      expect(received, 'hello');
    });

    test('filters events by type', () {
      final bus = EventBus();
      int? intReceived;
      String? strReceived;
      bus.on<int>().listen((e) => intReceived = e);
      bus.on<String>().listen((e) => strReceived = e);
      bus.fire(42);
      bus.fire('world');
      expect(intReceived, 42);
      expect(strReceived, 'world');
    });

    test('DataChangedEvent carries correct info', () {
      final bus = EventBus();
      DataChangedEvent? received;
      bus.on<DataChangedEvent>().listen((e) => received = e);
      bus.fire(
        const DataChangedEvent(
          'clients',
          resourceId: 'abc',
          changeType: ChangeType.deleted,
        ),
      );
      expect(received?.resourceType, 'clients');
      expect(received?.resourceId, 'abc');
      expect(received?.isDelete, true);
      expect(received?.isCreate, false);
    });

    test('broadcast stream can have multiple listeners', () {
      final bus = EventBus();
      int count = 0;
      bus.on<String>().listen((_) => count++);
      bus.on<String>().listen((_) => count++);
      bus.fire('test');
      expect(count, 2);
    });

    test('is singleton', () {
      final bus1 = EventBus();
      final bus2 = EventBus();
      expect(bus1, same(bus2));
    });
  });
}
