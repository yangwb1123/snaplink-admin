import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_plan_dialog.dart';
import 'package:sso_admin/screens/admin/recovery_dialogs.dart';
import 'package:sso_admin/screens/admin/scim/scim_models.dart';
import 'package:sso_admin/screens/admin/scim/scim_resource_detail_dialog.dart';
import 'package:sso_admin/screens/admin/scim/scim_user_dialog.dart';
import 'package:sso_admin/screens/oidc_login/federated_login.dart';

Future<void> _openDialog<T>(
  WidgetTester tester,
  Widget dialog,
  void Function(T?) onResult,
) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              final result = await showDialog<T>(
                context: context,
                builder: (_) => dialog,
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ScimUserDialog', () {
    testWidgets('creates a user draft with enterprise attributes', (
      tester,
    ) async {
      ScimUserDraft? draft;
      await _openDialog<ScimUserDraft>(
        tester,
        const ScimUserDialog(),
        (value) => draft = value,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'User name'),
        'ada',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Ada Lovelace',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Department'),
        'R&D',
      );
      await tester.tap(find.text('Create user'));
      await tester.pumpAndSettle();

      expect(draft, isNotNull);
      expect(draft!.userName, 'ada');
      expect(draft!.displayName, 'Ada Lovelace');
      expect(draft!.enterprise['department'], 'R&D');
    });

    testWidgets('requires a user name', (tester) async {
      ScimUserDraft? draft;
      await _openDialog<ScimUserDraft>(
        tester,
        const ScimUserDialog(),
        (value) => draft = value,
      );
      await tester.tap(find.text('Create user'));
      await tester.pumpAndSettle();
      expect(draft, isNull);
      expect(find.text('Required'), findsWidgets);
    });
  });

  group('ScimResourceDetailDialog', () {
    testWidgets('returns the patch action', (tester) async {
      ScimDetailAction? action;
      await _openDialog<ScimDetailAction>(
        tester,
        const ScimResourceDetailDialog(
          kind: ScimResourceKind.users,
          resource: {
            'id': 'user-1',
            'meta': {'version': 'v2'},
          },
        ),
        (value) => action = value,
      );
      expect(find.textContaining('user-1'), findsWidgets);
      await tester.tap(find.text('Patch'));
      await tester.pumpAndSettle();
      expect(action, ScimDetailAction.patch);
    });

    testWidgets('returns the delete action', (tester) async {
      ScimDetailAction? action;
      await _openDialog<ScimDetailAction>(
        tester,
        const ScimResourceDetailDialog(
          kind: ScimResourceKind.groups,
          resource: {'id': 'group-1'},
        ),
        (value) => action = value,
      );
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(action, ScimDetailAction.delete);
    });
  });

  group('CommercePlanDialog', () {
    testWidgets('returns a plan payload', (tester) async {
      Map<String, dynamic>? plan;
      await _openDialog<Map<String, dynamic>>(
        tester,
        const CommercePlanDialog(),
        (value) => plan = value,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Plan ID'),
        'enterprise',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Version'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Plan name'),
        'Enterprise',
      );
      await tester.tap(find.text('Publish plan'));
      await tester.pumpAndSettle();
      expect(plan, isNotNull);
      expect(plan!['name'], 'Enterprise');
    });
  });

  group('RecoveryDialogs', () {
    testWidgets('snapshot restore dialog returns a draft', (tester) async {
      SnapshotRestoreDraft? draft;
      await _openDialog<SnapshotRestoreDraft>(
        tester,
        SnapshotRestoreDialog(snapshotId: 'snap-1'),
        (value) => draft = value,
      );
      expect(find.textContaining('snap-1'), findsWidgets);
      // Dry-run is on by default; disable it to expose the restore action.
      await tester.tap(find.text('Dry run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(draft, isNotNull);
      expect(draft!.dryRun, isFalse);
    });
  });

  group('FederatedLogin', () {
    test('fails closed on the VM (no web console)', () {
      expect(
        () => FederatedLogin.beginLoginUrl(
          connectionId: 'okta',
          clientId: 'portal-client',
          redirectTarget: '/portal/',
        ),
        throwsStateError,
      );
      expect(FederatedLogin.hasPendingReturn(), isFalse);
    });
  });
}
