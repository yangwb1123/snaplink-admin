/// Route metadata for Snaplink governance capability groups.
class GovernanceReadSpec {
  final String section;
  final String key;
  final String title;
  final String path;

  const GovernanceReadSpec(this.section, this.key, this.title, this.path);

  factory GovernanceReadSpec.parse(String source) {
    final fields = source.split('\t');
    return GovernanceReadSpec(fields[0], fields[1], fields[2], fields[3]);
  }
}

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

final governanceReadSpecs = _readCatalog
    .trim()
    .split('\n')
    .map(GovernanceReadSpec.parse)
    .toList(growable: false);

const _readCatalog = '''
health\tstorage\tStorage health\t/api/v1/admin/storage-health
health\tfederation\tFederation health\t/api/v1/admin/federation/health
health\tdr\tDisaster recovery\t/api/v1/admin/dr/status
compliance\tdataMap\tData map\t/api/v1/admin/compliance/data-map
compliance\tsoc2\tSOC2 evidence\t/api/v1/admin/compliance/soc2-evidence
compliance\tconsents\tConsent inventory\t/api/v1/admin/compliance/consents
configuration\trunning\tRunning configuration\t/api/v1/admin/config/running
configuration\tapplied\tApplied configuration\t/api/v1/admin/config/applied
configuration\tdiff\tConfiguration diff\t/api/v1/admin/config/diff
configuration\thistory\tConfiguration history\t/api/v1/admin/config/history
lifecycle\tsnapshots\tSnapshots\t/api/v1/admin/snapshots
lifecycle\treleases\tRegistered releases\t/api/v1/admin/releases
lifecycle\tcurrentRelease\tCurrent release\t/api/v1/admin/releases:current
lifecycle\tchanges\tChange approvals\t/api/v1/admin/changes
''';

final governanceWriteOperations = _operationCatalog
    .trim()
    .split('\n')
    .map(GovernanceWriteOperation.parse)
    .toList(growable: false);

const _operationCatalog = '''
Create snapshot\tPOST\t/api/v1/admin/snapshots\t{"exclude":[]}
Restore snapshot\tPOST\t/api/v1/admin/snapshots/:id:restore\t{"mode":"merge","dry_run":true}
Delete snapshot\tDELETE\t/api/v1/admin/snapshots/:id\t{}
Register release\tPOST\t/api/v1/admin/releases\t{"release":{"channel":"stable","frontend":{"git_ref":""},"backend":{"git_ref":""}}}
Pin release\tPOST\t/api/v1/admin/releases/:id:pin\t{}
Rollback release\tPOST\t/api/v1/admin/releases/:id:rollback\t{}
Delete release\tDELETE\t/api/v1/admin/releases/:id\t{}
Set degradation mode\tPOST\t/api/v1/admin/dr/mode\t{"mode":"read_only","reason":"incident reference"}
Compare peer configuration\tPOST\t/api/v1/admin/config/cluster-diff\t{"snapshot":{}}
Run retention sweep\tPOST\t/api/v1/admin/compliance/retention-sweep\t{}
Create backup\tPOST\t/api/v1/admin/backup\t{}
Propose change\tPOST\t/api/v1/admin/changes\t{"action_type":"","payload":{},"reason":"ticket reference"}
Approve change\tPOST\t/api/v1/admin/changes/:id/approve\t{}
Reject change\tPOST\t/api/v1/admin/changes/:id/reject\t{}
''';
