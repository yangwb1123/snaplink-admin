/// Returns whether Forge credentials may be persisted by the native secure
/// storage plugin on [operatingSystem]. Web intentionally remains tab-scoped.
bool supportsSecureForgeCredentialsForPlatform(String operatingSystem) =>
    switch (operatingSystem) {
      'android' || 'ios' || 'linux' || 'macos' || 'windows' => true,
      _ => false,
    };
