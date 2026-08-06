"""Shared, environment-driven configuration for live integration tests."""

from dataclasses import dataclass
import os
from urllib.parse import urlsplit


class IntegrationConfigurationError(RuntimeError):
    """Raised when a live test is missing required configuration."""


def _origin(name: str, default: str) -> str:
    value = os.environ.get(name, default).strip().rstrip('/')
    parsed = urlsplit(value)
    if parsed.scheme not in {'http', 'https'} or not parsed.netloc:
        raise IntegrationConfigurationError(
            f'{name} must be an absolute HTTP(S) URL, got {value!r}'
        )
    if parsed.query or parsed.fragment:
        raise IntegrationConfigurationError(
            f'{name} must not contain a query or fragment'
        )
    return value


@dataclass(frozen=True)
class IntegrationConfig:
    api_url: str
    proxy_url: str
    username: str
    password: str
    client_id: str
    user_id: str

    @classmethod
    def from_environment(cls) -> 'IntegrationConfig':
        username = os.environ.get('SNAPLINK_TEST_USERNAME', '').strip()
        return cls(
            api_url=_origin('SNAPLINK_API_URL', 'http://localhost:8080'),
            proxy_url=_origin('SNAPLINK_PROXY_URL', 'http://localhost:4444'),
            username=username,
            password=os.environ.get('SNAPLINK_TEST_PASSWORD', ''),
            client_id=os.environ.get(
                'SNAPLINK_TEST_CLIENT_ID', 'sso-admin-console'
            ).strip(),
            user_id=os.environ.get('SNAPLINK_TEST_USER_ID', username).strip(),
        )

    @property
    def api_admin_url(self) -> str:
        return f'{self.api_url}/api/v1/admin'

    @property
    def proxy_host(self) -> str:
        return urlsplit(self.proxy_url).hostname or 'localhost'

    @property
    def proxy_port(self) -> int:
        parsed = urlsplit(self.proxy_url)
        return parsed.port or (443 if parsed.scheme == 'https' else 80)

    @property
    def api_host(self) -> str:
        return urlsplit(self.api_url).hostname or 'localhost'

    @property
    def api_port(self) -> int:
        parsed = urlsplit(self.api_url)
        return parsed.port or (443 if parsed.scheme == 'https' else 80)

    def require_credentials(self) -> None:
        missing = [
            name
            for name, value in (
                ('SNAPLINK_TEST_USERNAME', self.username),
                ('SNAPLINK_TEST_PASSWORD', self.password),
                ('SNAPLINK_TEST_USER_ID', self.user_id),
            )
            if not value
        ]
        if missing:
            raise IntegrationConfigurationError(
                'live authenticated tests require ' + ' and '.join(missing)
            )

    def login_payload(self, *, password: str | None = None) -> dict:
        self.require_credentials()
        return {
            'provider': 'password',
            'client_id': self.client_id,
            'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
            'credential': {
                'username': self.username,
                'password': self.password if password is None else password,
            },
        }

    def proxy_environment(self) -> dict[str, str]:
        environment = os.environ.copy()
        environment['PORT'] = str(self.proxy_port)
        environment['BACKEND'] = self.api_url
        return environment

    @property
    def manages_local_proxy(self) -> bool:
        configured = os.environ.get('SNAPLINK_MANAGE_PROXY')
        if configured is not None:
            return configured.strip().lower() in {'1', 'true', 'yes', 'on'}
        return self.proxy_host in {'localhost', '127.0.0.1', '::1'}


CONFIG = IntegrationConfig.from_environment()
