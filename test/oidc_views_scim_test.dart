import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/screens/admin/permissions_role_dialog.dart';
import 'package:sso_admin/screens/admin/scim/scim_group_dialog.dart';
import 'package:sso_admin/screens/admin/scim/scim_models.dart';
import 'package:sso_admin/screens/admin/scim/scim_patch_dialog.dart';
import 'package:sso_admin/screens/oidc_login/account_flow_views.dart';
import 'package:sso_admin/screens/oidc_login/branding_header.dart';
import 'package:sso_admin/screens/portal/portal_screen.dart';
import 'package:sso_admin/session.dart';

/// Opens [dialog] with a tall viewport (the patch dialog stacks several
/// rows) and reports the popped result through [onResult].
Future<void> _openDialog<T>(
  WidgetTester tester,
  Widget dialog,
  void Function(T?) onResult,
) async {
  tester.view.physicalSize = const Size(1200, 1600);
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
  tearDown(Session.clear);

  group('BrandingHeader', () {
    testWidgets('renders name and logo with brand color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandingHeader(
              brandLogoUrl: 'https://cdn.example/logo.png',
              brandName: 'Acme SSO',
              brandColor: const Color(0xFF123456),
            ),
          ),
        ),
      );
      expect(find.text('Acme SSO'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders an empty brand gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandingHeader())),
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('Account flow views', () {
    testWidgets('forgot-password view submits the identifier', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      var backed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordView(
              identifierController: controller,
              loading: false,
              error: 'Account not eligible',
              onSubmit: () => submitted = controller.text,
              onBack: () => backed = true,
            ),
          ),
        ),
      );

      expect(find.text('Account not eligible'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ada@example.com');
      await tester.tap(find.text('Send reset link'));
      expect(submitted, 'ada@example.com');
      await tester.tap(find.text('Back'));
      expect(backed, isTrue);
    });

    testWidgets('reset-password view forwards and surfaces errors', (
      tester,
    ) async {
      final password = TextEditingController();
      final confirm = TextEditingController();
      addTearDown(password.dispose);
      addTearDown(confirm.dispose);
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResetPasswordView(
              passwordController: password,
              confirmController: confirm,
              tokenAvailable: true,
              loading: false,
              onSubmit: () => submitted++,
              onBack: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'secret-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm new password'),
        'secret-1',
      );
      await tester.tap(find.text('Update password'));
      expect(submitted, 1);

      // Server-side errors surface in the view.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResetPasswordView(
              passwordController: password,
              confirmController: confirm,
              tokenAvailable: false,
              loading: false,
              error: 'This reset link is invalid.',
              onSubmit: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      expect(find.text('This reset link is invalid.'), findsOneWidget);
    });

    testWidgets('signup view collects credentials and submits', (tester) async {
      final username = TextEditingController();
      final email = TextEditingController();
      final password = TextEditingController();
      final confirm = TextEditingController();
      addTearDown(username.dispose);
      addTearDown(email.dispose);
      addTearDown(password.dispose);
      addTearDown(confirm.dispose);
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignupView(
              usernameController: username,
              emailController: email,
              passwordController: password,
              confirmController: confirm,
              loading: false,
              error: 'Username is taken',
              onSubmit: () => submitted++,
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.text('Username is taken'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ada');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email (optional)'),
        'ada@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'secret-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'secret-1',
      );
      await tester.tap(find.text('Create an account').last);
      expect(submitted, 1);
    });

    testWidgets('email verification and result views render', (tester) async {
      var verified = 0;
      var backed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmailVerificationView(
              tokenAvailable: true,
              loading: false,
              error: 'Expired link',
              onVerify: () => verified++,
              onBack: () => backed++,
            ),
          ),
        ),
      );
      expect(find.text('Expired link'), findsOneWidget);
      await tester.tap(find.text('Verify email'));
      expect(verified, 1);
      await tester.tap(find.text('Back'));
      expect(backed, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountFlowResultView(
              title: 'Email verified',
              message: 'You can now sign in.',
              onBack: () {},
            ),
          ),
        ),
      );
      expect(find.text('Email verified'), findsOneWidget);
      expect(find.text('You can now sign in.'), findsOneWidget);
    });
  });

  group('ScimGroupDialog', () {
    testWidgets('creates a group draft from name and members', (tester) async {
      ScimGroupDraft? draft;
      await _openDialog<ScimGroupDraft>(
        tester,
        const ScimGroupDialog(),
        (value) => draft = value,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'engineers',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Member user IDs'),
        'user-1, user-2',
      );
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      expect(draft, isNotNull);
      expect(draft!.displayName, 'engineers');
      expect(draft!.memberIds, ['user-1', 'user-2']);
    });

    testWidgets('editing pre-fills and reconciles members', (tester) async {
      ScimGroupDraft? draft;
      await _openDialog<ScimGroupDraft>(
        tester,
        const ScimGroupDialog(
          existing: {
            'displayName': 'ops',
            'members': [
              {'value': 'user-9'},
            ],
          },
        ),
        (value) => draft = value,
      );

      expect(find.text('Replace SCIM group'), findsOneWidget);
      await tester.tap(find.text('Replace group'));
      await tester.pumpAndSettle();
      expect(draft!.displayName, 'ops');
      expect(draft!.memberIds, ['user-9']);
    });
  });

  group('ScimPatchDialog', () {
    testWidgets('builds a valid replace operation body', (tester) async {
      Map<String, dynamic>? body;
      await _openDialog<Map<String, dynamic>>(
        tester,
        const ScimPatchDialog(
          kind: ScimResourceKind.users,
          resourceId: 'user-1',
        ),
        (value) => body = value,
      );

      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('false').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply patch'));
      await tester.pumpAndSettle();

      expect(body, isNotNull);
      final operations = body!['Operations'] as List;
      expect(operations.single['op'], 'replace');
      expect(operations.single['value'], isFalse);
    });

    testWidgets('member-by-ID row only allows remove', (tester) async {
      Map<String, dynamic>? body;
      await _openDialog<Map<String, dynamic>>(
        tester,
        const ScimPatchDialog(
          kind: ScimResourceKind.groups,
          resourceId: 'group-1',
        ),
        (value) => body = value,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      // Each row shows its current operation and path in the dropdowns.
      await tester.tap(find.text('replace').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('remove').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('displayName').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('member by ID').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Member user ID'),
        'user-42',
      );
      // The first row (replace displayName) needs a value to pass validation.
      await tester.enterText(
        find.widgetWithText(TextField, 'Value').first,
        'ops',
      );
      await tester.tap(find.text('Apply patch'));
      await tester.pumpAndSettle();

      expect(body, isNotNull);
      final operations = body!['Operations'] as List;
      expect(operations.last['path'], 'members[value eq "user-42"]');
    });
  });

  group('PermissionsRoleDialog', () {
    testWidgets('returns a draft with code and permissions', (tester) async {
      PermissionsRoleDraft? draft;
      await _openDialog<PermissionsRoleDraft>(
        tester,
        const PermissionsRoleDialog(),
        (value) => draft = value,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Role code'),
        'billing-admin',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(draft, isNotNull);
      expect(draft!.code, 'billing-admin');
    });
  });

  group('PortalScreen shell', () {
    testWidgets('renders the navigation shell after login', (tester) async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me') {
            return http.Response('{"sub":"user-1"}', 200);
          }
          if (request.url.path == '/me/notifications') {
            return http.Response(
              jsonEncode({'notifications': [], 'unread_count': 0}),
              200,
            );
          }
          if (request.url.path == '/me/notifications/stream') {
            return http.Response('', 200);
          }
          if (request.url.path == '/roles/me' ||
              request.url.path == '/permissions/me' ||
              request.url.path == '/menus/me') {
            return http.Response(jsonEncode({'items': []}), 200);
          }
          if (request.url.path == '/consents/me') {
            return http.Response(jsonEncode({'consents': []}), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PortalScreen(api: api, redirectMissingSessionToLogin: false),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'bearer-token');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The shell shows navigation destinations and the sign-out action.
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}
