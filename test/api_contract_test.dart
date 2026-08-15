// 历史遗留空占位文件（0 字节、无 main，导致全量套件加载失败并级联
// 拖垮同批次文件——R2 起记录的既有基线）。R10 终检补齐为合法空测试：
// API 契约相关断言由 api_paths_test / backend_contract_manifest_test /
// admin_contract_consistency_test 等真实套件承担，本文件仅作占位。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api contract placeholder (legacy empty file, no-op)', () {
    expect(true, isTrue);
  });
}
