import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';

/// Persona derivation vectors (design §3.2), the AdminModuleId link test
/// (T-persona-10), and the §4.9 order/emphasis pin tests (T-P-01..03).
void main() {
  group('deriveOperatorPersona — design §3.2 vectors', () {
    test('01: empty module set → general (total function, any commerce)', () {
      expect(
        deriveOperatorPersona(
          enabledModules: const {},
          commerceAvailable: false,
        ),
        OperatorPersona.general,
      );
      expect(
        deriveOperatorPersona(
          enabledModules: const {},
          commerceAvailable: true,
        ),
        OperatorPersona.general,
      );
    });

    test('02: core trio shell → general', () {
      expect(
        deriveOperatorPersona(
          enabledModules: const {'overview', 'clients', 'users', 'health'},
          commerceAvailable: true,
        ),
        OperatorPersona.general,
      );
    });

    test(
      '03: key/credential/DR constellation → securityOps (any commerce)',
      () {
        for (final commerce in [true, false]) {
          expect(
            deriveOperatorPersona(
              enabledModules: const {
                'crypto-keys',
                'credentials',
                'dr-mode',
                'threat-policies',
              },
              commerceAvailable: commerce,
            ),
            OperatorPersona.securityOps,
          );
        }
      },
    );

    test('04: identity constellation → identityOps', () {
      expect(
        deriveOperatorPersona(
          enabledModules: const {
            'local-users',
            'connections',
            'token-policies',
          },
          commerceAvailable: false,
        ),
        OperatorPersona.identityOps,
      );
    });

    test(
      '05: audit + privacy-compliance (no device-security/crypto) → auditor',
      () {
        expect(
          deriveOperatorPersona(
            enabledModules: const {'audit-log', 'privacy-compliance'},
            commerceAvailable: true,
          ),
          OperatorPersona.auditor,
        );
      },
    );

    test(
      '06: user-support + device-security (no crypto/credentials) → support',
      () {
        expect(
          deriveOperatorPersona(
            enabledModules: const {'user-support', 'device-security'},
            commerceAvailable: true,
          ),
          OperatorPersona.support,
        );
      },
    );

    test('07: full constellation + commerce → full', () {
      expect(
        deriveOperatorPersona(
          enabledModules: const {
            'crypto-keys',
            'credentials',
            'dr-mode',
            'threat-policies',
            'local-users',
            'connections',
            'governance',
          },
          commerceAvailable: true,
        ),
        OperatorPersona.full,
      );
    });

    test(
      '08: precedence — security constellation beats auditor w/o commerce',
      () {
        expect(
          deriveOperatorPersona(
            enabledModules: const {
              'audit-log',
              'privacy-compliance',
              'crypto-keys',
              'credentials',
              'dr-mode',
              'threat-policies',
            },
            commerceAvailable: false,
          ),
          OperatorPersona.securityOps,
        );
      },
    );

    test(
      '09: commerce gates full only (same set, probe down → securityOps)',
      () {
        expect(
          deriveOperatorPersona(
            enabledModules: const {
              'crypto-keys',
              'credentials',
              'dr-mode',
              'threat-policies',
              'local-users',
              'connections',
              'governance',
            },
            commerceAvailable: false,
          ),
          OperatorPersona.securityOps,
        );
      },
    );
  });

  group('PersonaModuleId ↔ AdminModuleId link (T-persona-10)', () {
    test('every PersonaModuleId constant equals its AdminModuleId twin', () {
      expect(PersonaModuleId.cryptoKeys, AdminModuleId.cryptoKeys);
      expect(PersonaModuleId.credentials, AdminModuleId.credentials);
      expect(PersonaModuleId.drMode, AdminModuleId.drMode);
      expect(PersonaModuleId.threatPolicies, AdminModuleId.threatPolicies);
      expect(PersonaModuleId.networkPolicies, AdminModuleId.networkPolicies);
      expect(PersonaModuleId.accessPolicies, AdminModuleId.accessPolicies);
      expect(PersonaModuleId.auditLog, AdminModuleId.auditLog);
      expect(
        PersonaModuleId.privacyCompliance,
        AdminModuleId.privacyCompliance,
      );
      expect(PersonaModuleId.governance, AdminModuleId.governance);
      expect(PersonaModuleId.changeApprovals, AdminModuleId.changeApprovals);
      expect(PersonaModuleId.deviceSecurity, AdminModuleId.deviceSecurity);
      expect(PersonaModuleId.userSupport, AdminModuleId.userSupport);
      expect(PersonaModuleId.emergencyAccess, AdminModuleId.emergencyAccess);
      expect(PersonaModuleId.liveActivity, AdminModuleId.liveActivity);
      expect(PersonaModuleId.localUsers, AdminModuleId.localUsers);
      expect(PersonaModuleId.scimDirectory, AdminModuleId.scimDirectory);
      expect(PersonaModuleId.connections, AdminModuleId.connections);
      expect(PersonaModuleId.permissions, AdminModuleId.permissions);
      expect(PersonaModuleId.domains, AdminModuleId.domains);
      expect(PersonaModuleId.tokenPolicies, AdminModuleId.tokenPolicies);
      expect(PersonaModuleId.tokenExchange, AdminModuleId.tokenExchange);
      expect(PersonaModuleId.organizations, AdminModuleId.organizations);
    });

    test('PersonaModuleId set is a subset of AdminModuleId values', () {
      final adminValues = <String>{
        for (final id in [
          AdminModuleId.overview,
          AdminModuleId.clients,
          AdminModuleId.users,
          AdminModuleId.localUsers,
          AdminModuleId.scimDirectory,
          AdminModuleId.permissions,
          AdminModuleId.connections,
          AdminModuleId.userSupport,
          AdminModuleId.deviceSecurity,
          AdminModuleId.liveActivity,
          AdminModuleId.tokenSecurity,
          AdminModuleId.usageAnalytics,
          AdminModuleId.tenants,
          AdminModuleId.commerce,
          AdminModuleId.organizations,
          AdminModuleId.operations,
          AdminModuleId.cryptoKeys,
          AdminModuleId.credentials,
          AdminModuleId.tokenPolicies,
          AdminModuleId.tokenExchange,
          AdminModuleId.authzChecks,
          AdminModuleId.domains,
          AdminModuleId.networkPolicies,
          AdminModuleId.accessPolicies,
          AdminModuleId.drMode,
          AdminModuleId.threatPolicies,
          AdminModuleId.webhooks,
          AdminModuleId.emergencyAccess,
          AdminModuleId.changeApprovals,
          AdminModuleId.recoveryReleases,
          AdminModuleId.privacyCompliance,
          AdminModuleId.governance,
          AdminModuleId.auditLog,
          AdminModuleId.health,
        ])
          id,
      };
      final personaIds = <String>{
        PersonaModuleId.cryptoKeys,
        PersonaModuleId.credentials,
        PersonaModuleId.drMode,
        PersonaModuleId.threatPolicies,
        PersonaModuleId.networkPolicies,
        PersonaModuleId.accessPolicies,
        PersonaModuleId.auditLog,
        PersonaModuleId.privacyCompliance,
        PersonaModuleId.governance,
        PersonaModuleId.changeApprovals,
        PersonaModuleId.deviceSecurity,
        PersonaModuleId.userSupport,
        PersonaModuleId.emergencyAccess,
        PersonaModuleId.liveActivity,
        PersonaModuleId.localUsers,
        PersonaModuleId.scimDirectory,
        PersonaModuleId.connections,
        PersonaModuleId.permissions,
        PersonaModuleId.domains,
        PersonaModuleId.tokenPolicies,
        PersonaModuleId.tokenExchange,
        PersonaModuleId.organizations,
      };
      expect(personaIds.difference(adminValues), isEmpty);
    });
  });

  group('personaLabelKey', () {
    test('maps every persona to its i18n source key', () {
      expect(personaLabelKey(OperatorPersona.full), 'Persona.full');
      expect(
        personaLabelKey(OperatorPersona.securityOps),
        'Persona.securityOps',
      );
      expect(personaLabelKey(OperatorPersona.auditor), 'Persona.auditor');
      expect(personaLabelKey(OperatorPersona.support), 'Persona.support');
      expect(
        personaLabelKey(OperatorPersona.identityOps),
        'Persona.identityOps',
      );
      expect(personaLabelKey(OperatorPersona.general), 'Persona.general');
    });
  });

  group(
    'T-P-01: every order helper returns a full permutation per persona',
    () {
      const personas = [
        OperatorPersona.full,
        OperatorPersona.securityOps,
        OperatorPersona.auditor,
        OperatorPersona.support,
        OperatorPersona.identityOps,
        OperatorPersona.general,
      ];

      void expectPermutation<T>(List<T> order, List<T> metricSet) {
        expect(order.length, metricSet.length, reason: 'no drops/duplicates');
        expect(order.toSet(), metricSet.toSet());
      }

      test('overviewMetricOrder (T-01)', () {
        const metrics = OverviewMetric.values;
        for (final p in personas) {
          expectPermutation(overviewMetricOrder(p), metrics.toList());
        }
        expect(overviewMetricOrder(OperatorPersona.general), const [
          OverviewMetric.liveEndpoints,
          OverviewMetric.featureGroups,
          OverviewMetric.documentedOnly,
          OverviewMetric.commerceAvailability,
        ]);
        expect(
          overviewMetricOrder(OperatorPersona.securityOps).first,
          OverviewMetric.documentedOnly,
        );
        expect(
          overviewMetricOrder(OperatorPersona.auditor).first,
          OverviewMetric.documentedOnly,
        );
        expect(
          overviewMetricOrder(OperatorPersona.identityOps).first,
          OverviewMetric.featureGroups,
        );
      });

      test('clientMetricOrder (T-02)', () {
        const metrics = ClientMetric.values;
        for (final p in personas) {
          expectPermutation(clientMetricOrder(p), metrics.toList());
        }
        expect(clientMetricOrder(OperatorPersona.general), const [
          ClientMetric.total,
          ClientMetric.active,
          ClientMetric.inactive,
          ClientMetric.secretsExpiring,
        ]);
        expect(
          clientMetricOrder(OperatorPersona.securityOps).first,
          ClientMetric.secretsExpiring,
        );
        expect(
          clientMetricOrder(OperatorPersona.identityOps).first,
          ClientMetric.active,
        );
        expect(
          clientMetricOrder(OperatorPersona.auditor).first,
          ClientMetric.secretsExpiring,
        );
      });

      test('userMetricOrder (T-03)', () {
        const metrics = UserMetric.values;
        for (final p in personas) {
          expectPermutation(userMetricOrder(p), metrics.toList());
        }
        expect(userMetricOrder(OperatorPersona.general), const [
          UserMetric.total,
          UserMetric.providers,
        ]);
        for (final p in [
          OperatorPersona.auditor,
          OperatorPersona.support,
          OperatorPersona.identityOps,
        ]) {
          expect(userMetricOrder(p), const [
            UserMetric.providers,
            UserMetric.total,
          ]);
        }
      });

      test('tenantMetricOrder (T-04)', () {
        const metrics = TenantMetric.values;
        for (final p in personas) {
          expectPermutation(tenantMetricOrder(p), metrics.toList());
        }
        expect(tenantMetricOrder(OperatorPersona.general), const [
          TenantMetric.total,
          TenantMetric.active,
          TenantMetric.suspended,
        ]);
        for (final p in [
          OperatorPersona.securityOps,
          OperatorPersona.auditor,
        ]) {
          expect(tenantMetricOrder(p), const [
            TenantMetric.suspended,
            TenantMetric.total,
            TenantMetric.active,
          ]);
        }
        expect(
          tenantMetricOrder(OperatorPersona.identityOps).first,
          TenantMetric.active,
        );
      });

      test('auditMetricOrder (T-05)', () {
        const metrics = AuditMetric.values;
        for (final p in personas) {
          expectPermutation(auditMetricOrder(p), metrics.toList());
        }
        expect(auditMetricOrder(OperatorPersona.general), const [
          AuditMetric.entries,
          AuditMetric.errorRate,
          AuditMetric.eventTypes,
        ]);
        for (final p in [
          OperatorPersona.securityOps,
          OperatorPersona.auditor,
        ]) {
          expect(auditMetricOrder(p), const [
            AuditMetric.errorRate,
            AuditMetric.entries,
            AuditMetric.eventTypes,
          ]);
        }
      });

      test('clientDetailMetricOrder (T-06)', () {
        const metrics = ClientDetailMetric.values;
        for (final p in personas) {
          expectPermutation(clientDetailMetricOrder(p), metrics.toList());
        }
        expect(clientDetailMetricOrder(OperatorPersona.general), const [
          ClientDetailMetric.grantTypes,
          ClientDetailMetric.scopes,
          ClientDetailMetric.secretExpiry,
        ]);
        for (final p in [
          OperatorPersona.securityOps,
          OperatorPersona.auditor,
        ]) {
          expect(clientDetailMetricOrder(p), const [
            ClientDetailMetric.secretExpiry,
            ClientDetailMetric.grantTypes,
            ClientDetailMetric.scopes,
          ]);
        }
      });

      test('tenantDetailMetricOrder (T-07)', () {
        const metrics = TenantDetailMetric.values;
        for (final p in personas) {
          expectPermutation(tenantDetailMetricOrder(p), metrics.toList());
        }
        expect(tenantDetailMetricOrder(OperatorPersona.general), const [
          TenantDetailMetric.members,
          TenantDetailMetric.invitations,
          TenantDetailMetric.residencyRegion,
        ]);
        expect(tenantDetailMetricOrder(OperatorPersona.identityOps), const [
          TenantDetailMetric.invitations,
          TenantDetailMetric.members,
          TenantDetailMetric.residencyRegion,
        ]);
      });
    },
  );

  group('T-P-02: bar emphasis matches design §4.9 T-08/T-09', () {
    test('clientsBarEmphasis', () {
      expect(clientsBarEmphasis(OperatorPersona.full), isNull);
      expect(clientsBarEmphasis(OperatorPersona.securityOps), isNull);
      expect(clientsBarEmphasis(OperatorPersona.auditor), 'Active');
      expect(clientsBarEmphasis(OperatorPersona.support), 'Active');
      expect(clientsBarEmphasis(OperatorPersona.identityOps), 'Active');
      expect(clientsBarEmphasis(OperatorPersona.general), isNull);
    });

    test('tenantsBarEmphasis', () {
      expect(tenantsBarEmphasis(OperatorPersona.full), isNull);
      expect(tenantsBarEmphasis(OperatorPersona.securityOps), 'Suspended');
      expect(tenantsBarEmphasis(OperatorPersona.auditor), 'Suspended');
      expect(tenantsBarEmphasis(OperatorPersona.support), 'Active');
      expect(tenantsBarEmphasis(OperatorPersona.identityOps), 'Active');
      expect(tenantsBarEmphasis(OperatorPersona.general), isNull);
    });
  });

  group('T-P-03: user detail screen is persona-invariant', () {
    test('user_detail_screen has no persona wiring or order helper', () {
      final source = File(
        'lib/screens/admin/user_detail_screen.dart',
      ).readAsStringSync();
      expect(source.contains('operator_persona'), isFalse);
      expect(source.contains('persona'), isFalse);
    });
  });
}
