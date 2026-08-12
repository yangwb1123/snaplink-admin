import 'package:flutter/material.dart';

/// Route metadata for Snaplink governance capability groups.
class GovernanceReadSpec {
  final String section;
  final String key;
  final String title;
  final String path;
  final IconData icon;

  const GovernanceReadSpec(
    this.section,
    this.key,
    this.title,
    this.path,
    this.icon,
  );

  factory GovernanceReadSpec.parse(String source) {
    final fields = source.split('\t');
    return GovernanceReadSpec(
      fields[0],
      fields[1],
      fields[2],
      fields[3],
      _specIcons[fields[4]] ?? Icons.description_outlined,
    );
  }
}

/// Icons per read spec, keyed by the catalog token (rendered with the
/// governance group accent via `adminModuleIconColor`).
const _specIcons = <String, IconData>{
  'storage': Icons.storage_outlined,
  'federation': Icons.account_tree_outlined,
  'dr': Icons.health_and_safety_outlined,
  'map': Icons.map_outlined,
  'soc2': Icons.verified_outlined,
  'consents': Icons.checklist_outlined,
  'running': Icons.tune_outlined,
  'applied': Icons.check_circle_outline,
  'diff': Icons.difference_outlined,
  'history': Icons.history,
  'snapshots': Icons.photo_library_outlined,
  'releases': Icons.rocket_launch_outlined,
  'current': Icons.push_pin_outlined,
  'changes': Icons.task_alt,
};

final governanceReadSpecs = _readCatalog
    .trim()
    .split('\n')
    .map(GovernanceReadSpec.parse)
    .toList(growable: false);

const _readCatalog = '''
health\tstorage\tStorage health\t/api/v1/admin/storage-health\tstorage
health\tfederation\tFederation health\t/api/v1/admin/federation/health\tfederation
health\tdr\tDisaster recovery\t/api/v1/admin/dr/status\tdr
compliance\tdataMap\tData map\t/api/v1/admin/compliance/data-map\tmap
compliance\tsoc2\tSOC2 evidence\t/api/v1/admin/compliance/soc2-evidence\tsoc2
compliance\tconsents\tConsent inventory\t/api/v1/admin/compliance/consents\tconsents
configuration\trunning\tRunning configuration\t/api/v1/admin/config/running\trunning
configuration\tapplied\tApplied configuration\t/api/v1/admin/config/applied\tapplied
configuration\tdiff\tConfiguration diff\t/api/v1/admin/config/diff\tdiff
configuration\thistory\tConfiguration history\t/api/v1/admin/config/history\thistory
lifecycle\tsnapshots\tSnapshots\t/api/v1/admin/snapshots\tsnapshots
lifecycle\treleases\tRegistered releases\t/api/v1/admin/releases\treleases
lifecycle\tcurrentRelease\tCurrent release\t/api/v1/admin/releases:current\tcurrent
lifecycle\tchanges\tChange approvals\t/api/v1/admin/changes\tchanges
''';

/// A governed operation rendered by the JSON write composer.
class GovernanceWriteOperation {
  final String label;
  final String method;
  final String path;
  final String example;

  const GovernanceWriteOperation(
    this.label,
    this.method,
    this.path,
    this.example,
  );

  factory GovernanceWriteOperation.parse(String source) {
    final fields = source.split('\t');
    return GovernanceWriteOperation(fields[0], fields[1], fields[2], fields[3]);
  }
}

final governanceWriteOperations = _operationCatalog
    .trim()
    .split('\n')
    .map(GovernanceWriteOperation.parse)
    .toList(growable: false);

const _operationCatalog = '''
Set degradation mode\tPOST\t/api/v1/admin/dr/mode\t{"mode":"read_only","reason":"incident reference"}
Compare peer configuration\tPOST\t/api/v1/admin/config/cluster-diff\t{"snapshot":{}}
Create backup\tPOST\t/api/v1/admin/backup\t{}
Propose change\tPOST\t/api/v1/admin/changes\t{"action_type":"","payload":{},"reason":"ticket reference"}
Approve change\tPOST\t/api/v1/admin/changes/:id/approve\t{}
Reject change\tPOST\t/api/v1/admin/changes/:id/reject\t{}
''';
