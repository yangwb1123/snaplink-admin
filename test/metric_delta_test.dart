import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/metric_delta.dart';

/// metricDelta honesty rules (design §2.1; T-MD-01..05): no trend → null.
void main() {
  test('T-MD-01: [1,2,3] → 50.0', () {
    expect(metricDelta(const [1, 2, 3]), 50.0);
  });

  test('T-MD-02: [5] → null (fewer than 2 points)', () {
    expect(metricDelta(const [5]), isNull);
  });

  test('T-MD-03: [0,10] → null (previous == 0 division guard)', () {
    expect(metricDelta(const [0, 10]), isNull);
  });

  test('T-MD-04: [-2,-1] → -50.0', () {
    expect(metricDelta(const [-2, -1]), -50.0);
  });

  test('T-MD-05: [10,10] → null (flat series)', () {
    expect(metricDelta(const [10, 10]), isNull);
  });
}
