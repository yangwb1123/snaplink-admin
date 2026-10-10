import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Libraries refactored across both batches. This protects part ownership;
/// repository acceptance still uses the unchanged engineering.yaml gates.
const _owners = [
  'lib/api/forge_device_placement.dart',
  'lib/api/forge_device_resource_summary.dart',
  'lib/api/forge_scheduler_selection_lease.dart',
  'lib/api/forge_device_inventory_placement_evaluation_v2.dart',
  'lib/api/forge_device_inventory_persistence.dart',
  'lib/api/forge_runner_terminal_receipt.dart',
  'lib/api/forge_device_credential_candidate.dart',
  'lib/api/forge_runner_dispatch_plan_preview.dart',
  'lib/api/forge_device_inventory_v2_models.dart',
  'lib/api/forge_pending_run_intent.dart',
  'lib/api/forge_runner_lease_fencing.dart',
  'lib/api/forge_runner_execution_intent.dart',
  'lib/api/forge_conversations_models.dart',
  'lib/api/forge_execution_lease_checkpoint.dart',
  'lib/api/forge_execution_reconciliation_observation.dart',
  'lib/api/forge_device_registry_placement_preview.dart',
  'lib/api/forge_runner_transport_admission.dart',
  'lib/api/forge_conversations_api.dart',
  'lib/forge_android_instrumentation_entrypoint.dart',
  'lib/screens/forge/forge_sessions_device_observation.dart',
  'lib/screens/forge/forge_sessions_screen.dart',
  'lib/screens/forge/forge_sessions_gate.dart',
  'lib/screens/agent/agent_operations_screen.dart',
  'lib/app_settings.dart',
];

final _part = RegExp(r'''^part ['"]([^'"]+)['"];\s*$''', multiLine: true);
final _partOf = RegExp(r'''^part of ['"]([^'"]+)['"];\s*$''', multiLine: true);

File _resolve(File owner, String relative) =>
    File.fromUri(owner.absolute.uri.resolve(relative));

void main() {
  for (final path in _owners) {
    test('$path: bounded, uniquely owned parts stay in the same library', () {
      final owner = File(path);
      final source = owner.readAsStringSync();
      expect(
        const LineSplitter().convert(source).length,
        lessThanOrEqualTo(400),
      );
      expect(_partOf.hasMatch(source), isFalse);
      final seen = <String>{};
      final parts = _part.allMatches(source).toList();
      expect(parts, isNotEmpty);
      for (final match in parts) {
        final part = _resolve(owner, match[1]!);
        expect(
          seen.add(part.absolute.path),
          isTrue,
          reason: 'A part must be registered exactly once: ${part.path}',
        );
        expect(part.existsSync(), isTrue);
        final body = part.readAsStringSync();
        expect(
          const LineSplitter().convert(body).length,
          lessThanOrEqualTo(400),
          reason: part.path,
        );
        final declaration = _partOf.allMatches(body).toList();
        expect(declaration, hasLength(1), reason: part.path);
        expect(
          _resolve(part, declaration.single[1]!).absolute.path,
          owner.absolute.path,
          reason: part.path,
        );
        expect(
          _part.hasMatch(body),
          isFalse,
          reason: 'Parts cannot form a second library: ${part.path}',
        );
        expect(
          RegExp(r'^\s*(?:import|export)\s', multiLine: true).hasMatch(body),
          isFalse,
          reason: 'The owning library retains imports: ${part.path}',
        );
      }
    });
  }

  test(
    'every part in the refactored libraries has exactly one registration',
    () {
      final registrations = <String, List<String>>{};
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final match in _part.allMatches(file.readAsStringSync())) {
          final target = _resolve(file, match[1]!).absolute.path;
          registrations.putIfAbsent(target, () => []).add(file.path);
        }
      }
      for (final path in _owners) {
        final owner = File(path);
        for (final match in _part.allMatches(owner.readAsStringSync())) {
          final target = _resolve(owner, match[1]!).absolute.path;
          expect(registrations[target], [owner.path], reason: target);
        }
      }
    },
  );
}
