import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/recovery_dialogs.dart';

void main() {
  test('restore preview key binds every mutating option', () {
    const preview = SnapshotRestoreDraft(
      mode: 'overwrite',
      dryRun: true,
      advanceBootstrap: false,
      exclude: ['sessions', 'tokens'],
    );
    const sameCommit = SnapshotRestoreDraft(
      mode: 'overwrite',
      dryRun: false,
      advanceBootstrap: false,
      exclude: ['tokens', 'sessions'],
    );
    const changedCommit = SnapshotRestoreDraft(
      mode: 'replace',
      dryRun: false,
      advanceBootstrap: false,
      exclude: ['tokens', 'sessions'],
    );

    expect(
      preview.previewKey('snapshot-1'),
      sameCommit.previewKey('snapshot-1'),
    );
    expect(
      preview.previewKey('snapshot-1'),
      isNot(changedCommit.previewKey('snapshot-1')),
    );
    expect(
      preview.previewKey('snapshot-1'),
      isNot(sameCommit.previewKey('snapshot-2')),
    );
  });
}
