/// B6-1b storage-seam behavior tests (seam design §1.5, spec REQ-4).
///
/// Per-file-isolate singleton semantics: `_load()` runs exactly once per
/// file, at the first `AuditLogService()` construction. Hence the
/// **construction-order contract**: the load-off test below MUST be the
/// first test in this file, and its teardown must remove the seeded key
/// so later tests observe clean storage. Test order within the file is
/// declaration order (the flutter_test default). The `debugStorageEnabled`
/// axis is `@visibleForTesting`; `removeItem`/the key literal are allowed
/// in test code (C8 — scans scope to `lib/` only).
///
/// These tests own the write-path half of the T-12 joint (REQ-3 R3.4):
/// flag off ⇒ no read, no write, no remove; flag on ⇒ the ring persists
/// with intact wire fields. The F6 boundary (IO swapped between the two
/// gated functions) is documented in the mutation drill as scan-7-green;
/// the flag-on assertions here go red on that swap.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/local_storage.dart';

const _forgedPayload =
    '[{"timestamp":"2026-08-05T12:00:00.000Z","method":"POST",'
    '"path":"/api/v1/admin/forged","statusCode":200,"label":"forged entry"}]';

AuditEntry _entry(String path, String label) => AuditEntry(
  timestamp: DateTime.now(),
  method: 'POST',
  path: path,
  statusCode: 200,
  label: label,
);

void main() {
  group('B6-1b storage seam — write-path isolation (AC-1 / AC-2 / AC-4)', () {
    test('load path, flag off — first-test construction-order contract', () {
      // FIRST construction of AuditLogService in this isolate: the flag
      // must be off before the constructor's `_load()` runs, or the
      // seeded payload would be consumed and this test would pass
      // vacuously (FD-4).
      AuditLogService.debugStorageEnabled = false;
      LocalStorage.setItem('sso_audit_log', _forgedPayload);
      addTearDown(() => LocalStorage.removeItem('sso_audit_log'));

      final service = AuditLogService();
      expect(
        service.entries,
        isEmpty,
        reason: 'gated _load must not read the seeded payload',
      );
      // Stored payload byte-identical, key still present — no read, no
      // removeItem from lib/ (R1.7).
      expect(LocalStorage.getItem('sso_audit_log'), _forgedPayload);
      expect(LocalStorage.keys(), contains('sso_audit_log'));
    });

    test('flag-off persistence — record()/clear() never write the key', () {
      AuditLogService.debugStorageEnabled = false;
      LocalStorage.setItem('sso_audit_log', _forgedPayload);
      addTearDown(() => LocalStorage.removeItem('sso_audit_log'));

      final service = AuditLogService();
      service.record(_entry('/api/v1/admin/clients', 'Create clients'));
      service.record(_entry('/api/v1/admin/users', 'Create users'));
      service.record(_entry('/api/v1/admin/roles', 'Delete roles'));
      service.clear();
      // _save no-ops with the flag off: the pre-seeded payload is
      // byte-identical (write isolation).
      expect(LocalStorage.getItem('sso_audit_log'), _forgedPayload);
      expect(LocalStorage.keys(), contains('sso_audit_log'));
    });

    test('write path, flag off — memory-only ring keeps its public API', () {
      AuditLogService.debugStorageEnabled = false;
      addTearDown(() {
        AuditLogService.debugStorageEnabled = true;
        AuditLogService().clear();
        LocalStorage.removeItem('sso_audit_log');
      });

      final service = AuditLogService();
      service.record(_entry('/api/v1/admin/clients', 'Create clients'));
      service.record(_entry('/api/v1/admin/users', 'Create users'));
      service.record(_entry('/api/v1/admin/roles', 'Delete roles'));
      // Nothing reached storage.
      expect(LocalStorage.keys(), isNot(contains('sso_audit_log')));
      expect(LocalStorage.getItem('sso_audit_log'), isNull);
      // In-memory surface intact (C3).
      expect(service.count, 3);
      expect(service.entries, hasLength(3));
      expect(service.search('users'), hasLength(1));
      expect(service.filterByMethod('POST'), hasLength(3));
      expect(service.filterByMethod('GET'), isEmpty);
      expect(service.recent(const Duration(minutes: 5)), hasLength(3));
      service.clear();
      expect(service.count, 0);
    });

    test('write path, flag on — ring persists with intact wire fields', () {
      AuditLogService.debugStorageEnabled = true;
      addTearDown(() {
        AuditLogService.debugStorageEnabled = true;
        AuditLogService().clear();
        LocalStorage.removeItem('sso_audit_log');
      });

      final service = AuditLogService();
      service.clear();
      service.record(_entry('/api/v1/admin/clients', 'Create clients'));
      service.record(_entry('/api/v1/admin/users', 'Create users'));
      service.record(_entry('/api/v1/admin/roles', 'Delete roles'));
      expect(LocalStorage.keys(), contains('sso_audit_log'));
      final raw = LocalStorage.getItem('sso_audit_log');
      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List;
      expect(list, hasLength(3));
      // First entry is most recent; wire fields intact.
      final first = list.first as Map<String, dynamic>;
      expect(first['path'], '/api/v1/admin/roles');
      for (final row in list.cast<Map<String, dynamic>>()) {
        expect(row.keys.toSet(), {
          'timestamp',
          'method',
          'path',
          'statusCode',
          'label',
        });
      }
      // clear() persists the empty ring.
      service.clear();
      expect(LocalStorage.getItem('sso_audit_log'), '[]');
    });
  });
}
