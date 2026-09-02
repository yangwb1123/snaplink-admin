from pathlib import Path
import os
import subprocess
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]


def section_between(document, start, end):
    return document.split(start, 1)[1].split(end, 1)[0]


def render_kustomize(profile):
    result = subprocess.run(
        ['kubectl', 'kustomize', str(ROOT / 'k8s' / profile)],
        capture_output=True,
        check=True,
        text=True,
    )
    return list(yaml.safe_load_all(result.stdout))


class DeploymentContractsTest(unittest.TestCase):
    def test_compose_wires_console_to_healthy_backend(self):
        compose = yaml.safe_load((ROOT / 'docker-compose.yml').read_text())
        services = compose['services']
        backend = services['snaplink']
        console = services['console']

        self.assertIn('healthcheck', backend)
        self.assertEqual(
            console['depends_on']['snaplink']['condition'],
            'service_healthy',
        )
        self.assertEqual(
            console['environment']['SNAPLINK_UPSTREAM'],
            'http://snaplink:8080',
        )
        self.assertEqual(
            console['environment']['SNAPLINK_SERVER_NAME'],
            '${SNAPLINK_SERVER_NAME:-snaplink}',
        )
        self.assertEqual(
            console['build']['args']['SNAPLINK_ADMIN_OAUTH_RESOURCES'],
            '${SNAPLINK_ADMIN_OAUTH_RESOURCES-billing-api,stripe-adapter-api,audit-governance}',
        )
        self.assertEqual(
            console['environment']['SNAPLINK_BILLING_UPSTREAM'],
            '${SNAPLINK_BILLING_UPSTREAM:?SNAPLINK_BILLING_UPSTREAM must be set — no implicit sso-server fallback (P0-2)}',
        )
        self.assertEqual(
            console['environment']['SNAPLINK_STRIPE_ADAPTER_UPSTREAM'],
            '${SNAPLINK_STRIPE_ADAPTER_UPSTREAM:?SNAPLINK_STRIPE_ADAPTER_UPSTREAM must be set — no implicit sso-server fallback (P0-2)}',
        )
        self.assertEqual(
            console['environment']['AUDIT_GOVERNANCE_UPSTREAM'],
            '${AUDIT_GOVERNANCE_UPSTREAM:?AUDIT_GOVERNANCE_UPSTREAM must be set — audit reads have no local fallback}',
        )
        self.assertIn('4444:80', console['ports'])

    def test_kubernetes_workload_preserves_non_root_read_only_runtime(self):
        documents = list(
            yaml.safe_load_all((ROOT / 'k8s/base/deployment.yaml').read_text())
        )
        deployment = next(item for item in documents if item['kind'] == 'Deployment')
        pdb = next(item for item in documents if item['kind'] == 'PodDisruptionBudget')
        hpa = next(item for item in documents if item['kind'] == 'HorizontalPodAutoscaler')
        container = deployment['spec']['template']['spec']['containers'][0]
        environment = {item['name']: item['value'] for item in container['env']}
        mounts = {item['mountPath'] for item in container['volumeMounts']}

        self.assertEqual(
            environment['SNAPLINK_UPSTREAM'],
            'http://sso-server.sv-sso.svc.cluster.local:8080',
        )
        self.assertEqual(
            environment['SNAPLINK_SERVER_NAME'],
            'sso-server.sv-sso.svc.cluster.local',
        )
        self.assertEqual(
            environment['SNAPLINK_CA'],
            '/etc/ssl/certs/ca-certificates.crt',
        )
        self.assertEqual(
            environment['SNAPLINK_BILLING_UPSTREAM'],
            'https://snaplink-billing.sv-sso.svc.cluster.local:443',
        )
        self.assertEqual(
            environment['SNAPLINK_BILLING_CA'],
            '/etc/snaplink-billing/ca/ca.crt',
        )
        self.assertEqual(
            environment['SNAPLINK_STRIPE_ADAPTER_UPSTREAM'],
            'https://snaplink-stripe-adapter.sv-sso.svc.cluster.local:443',
        )
        self.assertEqual(
            environment['SNAPLINK_STRIPE_ADAPTER_CA'],
            '/etc/snaplink-stripe-adapter/ca/ca.crt',
        )
        self.assertEqual(
            environment['AUDIT_GOVERNANCE_UPSTREAM'],
            'http://audit-governance.sv-sso.svc.cluster.local:8089',
        )
        self.assertTrue(container['securityContext']['readOnlyRootFilesystem'])
        self.assertFalse(container['securityContext']['allowPrivilegeEscalation'])
        self.assertIn('readinessProbe', container)
        self.assertIn('livenessProbe', container)
        self.assertTrue(
            {'/etc/nginx/conf.d', '/var/cache/nginx', '/run'} <= mounts
        )
        self.assertGreaterEqual(deployment['spec']['replicas'], 3)
        self.assertEqual(deployment['spec']['strategy']['rollingUpdate']['maxUnavailable'], 0)
        self.assertEqual(pdb['spec']['minAvailable'], 2)
        self.assertEqual(hpa['spec']['minReplicas'], 3)
        self.assertIn('topologySpreadConstraints', deployment['spec']['template']['spec'])

    def test_kubernetes_profiles_render_full_and_dns_safe_minimal_workloads(self):
        minimal = render_kustomize('minimal')
        full = render_kustomize('full')
        minimal_deployment = next(
            item for item in minimal if item['kind'] == 'Deployment'
        )
        full_deployment = next(item for item in full if item['kind'] == 'Deployment')

        minimal_pod = minimal_deployment['spec']['template']['spec']
        minimal_container = minimal_pod['containers'][0]
        minimal_environment = {
            item['name']: item['value'] for item in minimal_container['env']
        }
        minimal_mounts = {
            item['name'] for item in minimal_container.get('volumeMounts', [])
        }
        minimal_volumes = {item['name'] for item in minimal_pod.get('volumes', [])}
        snaplink_origin = minimal_environment['SNAPLINK_UPSTREAM']

        self.assertEqual(minimal_environment['SNAPLINK_BILLING_UPSTREAM'], snaplink_origin)
        self.assertEqual(
            minimal_environment['SNAPLINK_STRIPE_ADAPTER_UPSTREAM'],
            snaplink_origin,
        )
        self.assertNotIn('billing-ca', minimal_mounts | minimal_volumes)
        self.assertNotIn('stripe-adapter-ca', minimal_mounts | minimal_volumes)

        full_pod = full_deployment['spec']['template']['spec']
        full_container = full_pod['containers'][0]
        full_environment = {
            item['name']: item['value'] for item in full_container['env']
        }
        full_mounts = {item['name'] for item in full_container['volumeMounts']}
        self.assertNotEqual(
            full_environment['SNAPLINK_BILLING_UPSTREAM'],
            full_environment['SNAPLINK_UPSTREAM'],
        )
        self.assertNotEqual(
            full_environment['SNAPLINK_STRIPE_ADAPTER_UPSTREAM'],
            full_environment['SNAPLINK_UPSTREAM'],
        )
        self.assertIn('billing-ca', full_mounts)
        self.assertIn('stripe-adapter-ca', full_mounts)

    def test_image_and_nginx_share_the_app_prefix_and_upstream_contract(self):
        dockerfile = (ROOT / 'Dockerfile').read_text()
        nginx = (ROOT / 'nginx.conf').read_text()
        preflight = (
            ROOT / 'docker-entrypoint.d/10-validate-upstreams.sh'
        ).read_text()

        self.assertIn('ARG SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api,audit-governance', dockerfile)
        self.assertIn('ARG FLUTTER_VERSION=3.47.1', dockerfile)
        self.assertRegex(
            dockerfile,
            r'ARG FLUTTER_SHA256=[0-9a-f]{64}',
        )
        self.assertIn(
            'flutter_linux_${FLUTTER_VERSION}-stable.tar.xz',
            dockerfile,
        )
        self.assertIn('sha256sum -c -', dockerfile)
        self.assertIn('tar xJf /tmp/flutter.tar.xz -C /opt', dockerfile)
        self.assertIn('--dart-define=SNAPLINK_ADMIN_OAUTH_RESOURCES=', dockerfile)
        # The image must build the same code-split dart2js bundle as
        # `make build-prod` (deferred chunks; dart2wasm does not emit chunks).
        self.assertIn(
            'flutter build web --release --base-href=/app/',
            dockerfile,
        )
        self.assertIn(
            'COPY nginx.conf /etc/nginx/templates/default.conf.template',
            dockerfile,
        )
        self.assertIn(
            'COPY docker-entrypoint.d/10-validate-upstreams.sh /docker-entrypoint.d/10-validate-upstreams.sh',
            dockerfile,
        )
        self.assertIn('RUN chmod +x /docker-entrypoint.d/10-validate-upstreams.sh', dockerfile)
        self.assertIn('validate_origin SNAPLINK_BILLING_UPSTREAM', preflight)
        self.assertIn('validate_origin SNAPLINK_STRIPE_ADAPTER_UPSTREAM', preflight)
        self.assertIn('validate_origin SNAPLINK_UPSTREAM', preflight)
        self.assertIn('validate_origin AUDIT_GOVERNANCE_UPSTREAM', preflight)
        self.assertIn('must be an explicit http:// or https:// origin', preflight)
        self.assertIn('ENV SNAPLINK_UPSTREAM=http://snaplink:8080', dockerfile)
        self.assertIn('ENV SNAPLINK_SERVER_NAME=snaplink', dockerfile)
        self.assertIn(
            'ENV SNAPLINK_CA=/etc/ssl/certs/ca-certificates.crt',
            dockerfile,
        )
        self.assertIn(
            'ENV SNAPLINK_BILLING_UPSTREAM=',
            dockerfile,
        )
        self.assertIn('ENV SNAPLINK_STRIPE_ADAPTER_UPSTREAM=', dockerfile)
        self.assertIn('ENV AUDIT_GOVERNANCE_UPSTREAM=', dockerfile)
        self.assertIn('location ^~ /app/', nginx)
        self.assertIn('proxy_pass ${SNAPLINK_UPSTREAM};', nginx)
        self.assertIn('proxy_pass ${SNAPLINK_BILLING_UPSTREAM};', nginx)
        self.assertIn('proxy_pass ${SNAPLINK_STRIPE_ADAPTER_UPSTREAM};', nginx)
        self.assertEqual(nginx.count('proxy_ssl_verify on;'), 7)
        self.assertEqual(nginx.count('proxy_ssl_name ${SNAPLINK_SERVER_NAME};'), 2)
        self.assertEqual(
            nginx.count('proxy_ssl_trusted_certificate ${SNAPLINK_CA};'),
            2,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_name ${SNAPLINK_BILLING_SERVER_NAME};'),
            1,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_trusted_certificate ${SNAPLINK_BILLING_CA};'),
            1,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_name ${SNAPLINK_STRIPE_ADAPTER_SERVER_NAME};'),
            1,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_trusted_certificate ${SNAPLINK_STRIPE_ADAPTER_CA};'),
            1,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_name ${AUDIT_GOVERNANCE_SERVER_NAME};'),
            3,
        )
        self.assertEqual(
            nginx.count('proxy_ssl_trusted_certificate ${AUDIT_GOVERNANCE_CA};'),
            3,
        )
        device = section_between(
            nginx,
            'location @snaplink_device_verify {',
            '# Billing remains an API-only service.',
        )
        billing = section_between(
            nginx,
            'location ~ ^/api/v1/(?:admin/commerce|commerce|metering)(?:/|$) {',
            '# Checkout is an exact, opt-in adapter route.',
        )
        stripe = section_between(
            nginx,
            'location = /api/v1/checkout/sessions {',
            '# Same-origin Snaplink endpoints',
        )
        snaplink = section_between(
            nginx,
            'location ~ ^/(?:auth/|api/|me',
            '# Six product routes',
        )
        self.assertIn('proxy_ssl_name ${SNAPLINK_SERVER_NAME};', device)
        self.assertIn('proxy_ssl_trusted_certificate ${SNAPLINK_CA};', device)
        self.assertIn('proxy_ssl_name ${SNAPLINK_SERVER_NAME};', snaplink)
        self.assertIn('proxy_ssl_trusted_certificate ${SNAPLINK_CA};', snaplink)
        self.assertIn('proxy_ssl_name ${SNAPLINK_BILLING_SERVER_NAME};', billing)
        self.assertIn(
            'proxy_ssl_trusted_certificate ${SNAPLINK_BILLING_CA};',
            billing,
        )
        self.assertIn(
            'proxy_ssl_name ${SNAPLINK_STRIPE_ADAPTER_SERVER_NAME};',
            stripe,
        )
        self.assertIn(
            'proxy_ssl_trusted_certificate ${SNAPLINK_STRIPE_ADAPTER_CA};',
            stripe,
        )
        self.assertNotIn('SNAPLINK_BILLING_', device + snaplink)
        self.assertNotIn('SNAPLINK_STRIPE_ADAPTER_', device + snaplink + billing)
        self.assertIn('location = /api/v1/checkout/sessions', nginx)
        self.assertIn('admin/commerce|commerce|metering', nginx)
        self.assertIn('location = /api/v1/audit/events', nginx)
        self.assertIn('location = /api/v1/audit/facets', nginx)
        self.assertIn('/api/v1/compat/snaplink/audit/events break;', nginx)
        self.assertIn('/api/v1/compat/snaplink/audit/facets break;', nginx)
        self.assertIn('/api/v1/compat/snaplink/audit/events/$1 break;', nginx)
        self.assertIn('location = /device/verify', nginx)
        self.assertIn('register(?:/|$)', nginx)

    def test_optional_upstream_preflight_rejects_implicit_fallbacks(self):
        script = ROOT / 'docker-entrypoint.d/10-validate-upstreams.sh'
        environment = os.environ.copy()
        environment.update(
            {
                'SNAPLINK_UPSTREAM': 'http://snaplink:8080',
                'SNAPLINK_BILLING_UPSTREAM': 'http://billing:8080',
                'SNAPLINK_STRIPE_ADAPTER_UPSTREAM': 'https://stripe:443',
                'AUDIT_GOVERNANCE_UPSTREAM': 'http://audit-governance:8089',
            }
        )
        valid = subprocess.run(
            ['sh', str(script)],
            capture_output=True,
            check=False,
            text=True,
            env=environment,
        )
        self.assertEqual(valid.returncode, 0, valid.stderr)

        for invalid in ('', 'http://billing/api', 'billing:8080'):
            environment['SNAPLINK_BILLING_UPSTREAM'] = invalid
            result = subprocess.run(
                ['sh', str(script)],
                capture_output=True,
                check=False,
                text=True,
                env=environment,
            )
            self.assertNotEqual(result.returncode, 0, invalid)
            self.assertIn('SNAPLINK_BILLING_UPSTREAM', result.stderr)

    def test_core_upstream_preflight_rejects_invalid_origin(self):
        script = ROOT / 'docker-entrypoint.d/10-validate-upstreams.sh'
        environment = os.environ.copy()
        environment.update(
            {
                'SNAPLINK_UPSTREAM': 'http://snaplink:8080',
                'SNAPLINK_BILLING_UPSTREAM': 'http://billing:8080',
                'SNAPLINK_STRIPE_ADAPTER_UPSTREAM': 'https://stripe:443',
                'AUDIT_GOVERNANCE_UPSTREAM': 'http://audit-governance:8089',
            }
        )

        for invalid in ('', 'http://snaplink/api', 'snaplink:8080'):
            environment['SNAPLINK_UPSTREAM'] = invalid
            result = subprocess.run(
                ['sh', str(script)],
                capture_output=True,
                check=False,
                text=True,
                env=environment,
            )
            self.assertNotEqual(result.returncode, 0, invalid)
            self.assertIn('SNAPLINK_UPSTREAM', result.stderr)

    def test_ci_installs_declared_tools_and_scopes_fixture_credentials(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/ci.yml').read_text())
        check_steps = workflow['jobs']['check']['steps']
        integration_steps = workflow['jobs']['integration']['steps']
        install = next(step for step in check_steps if step.get('name') == 'Install dependencies')
        live_test = next(
            step for step in integration_steps if step.get('name') == 'Integration tests'
        )
        browser_test = next(
            step for step in check_steps if step.get('name') == 'Browser tests'
        )
        kubernetes_setup = next(
            step for step in check_steps if step.get('name') == 'Setup kubectl'
        )
        kubernetes_render = next(
            step
            for step in check_steps
            if step.get('name') == 'Kubernetes profile renders'
        )

        self.assertIn('pip install -r requirements-dev.txt', install['run'])
        self.assertEqual(live_test['env']['SNAPLINK_TEST_USERNAME'], 'admin')
        self.assertEqual(live_test['env']['SNAPLINK_TEST_PASSWORD'], 'admin')
        self.assertEqual(browser_test['run'], 'make test-browser')
        self.assertEqual(kubernetes_setup['uses'], 'azure/setup-kubectl@v4')
        self.assertEqual(kubernetes_render['run'], 'make k8s-render')


if __name__ == '__main__':
    unittest.main()
