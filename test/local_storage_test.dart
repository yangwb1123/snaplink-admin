import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/local_storage.dart';

void main() {
  const firstKey = 'local_storage_test_first';
  const secondKey = 'local_storage_test_second';

  setUp(() {
    LocalStorage.removeItem(firstKey);
    LocalStorage.removeItem(secondKey);
  });

  tearDown(() {
    LocalStorage.removeItem(firstKey);
    LocalStorage.removeItem(secondKey);
  });

  test('stores, reads, and overwrites values on the VM implementation', () {
    expect(LocalStorage.getItem(firstKey), isNull);

    LocalStorage.setItem(firstKey, 'first');
    expect(LocalStorage.getItem(firstKey), 'first');

    LocalStorage.setItem(firstKey, 'updated');
    expect(LocalStorage.getItem(firstKey), 'updated');
  });

  test('removes only the requested value', () {
    LocalStorage.setItem(firstKey, 'first');
    LocalStorage.setItem(secondKey, 'second');
    expect(LocalStorage.keys(), containsAll([firstKey, secondKey]));

    LocalStorage.removeItem(firstKey);

    expect(LocalStorage.getItem(firstKey), isNull);
    expect(LocalStorage.getItem(secondKey), 'second');
  });
}
