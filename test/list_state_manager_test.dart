import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/list_state_manager.dart';

void main() {
  group('ListStateManager', () {
    test('saves and restores state', () {
      final mgr = ListStateManager();
      mgr.save('test_list', {'filter': 'active', 'page': 2});
      final restored = mgr.restore('test_list');
      expect(restored, isNotNull);
      expect(restored!['filter'], 'active');
      expect(restored['page'], 2);
    });

    test('returns null for unknown key', () {
      final mgr = ListStateManager();
      expect(mgr.restore('nonexistent'), isNull);
    });

    test('clear removes saved state', () {
      final mgr = ListStateManager();
      mgr.save('test_list', {'filter': 'test'});
      mgr.clear('test_list');
      expect(mgr.restore('test_list'), isNull);
    });

    test('clearAll removes all states', () {
      final mgr = ListStateManager();
      mgr.save('list_a', {'a': 1});
      mgr.save('list_b', {'b': 2});
      mgr.clearAll();
      expect(mgr.restore('list_a'), isNull);
      expect(mgr.restore('list_b'), isNull);
    });

    test('overwrite updates existing state', () {
      final mgr = ListStateManager();
      mgr.save('test_list', {'version': 1});
      mgr.save('test_list', {'version': 2});
      final restored = mgr.restore('test_list');
      expect(restored!['version'], 2);
    });
  });
}
