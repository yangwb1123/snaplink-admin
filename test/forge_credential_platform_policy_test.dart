import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/forge_credential_platform_policy.dart';

void main() {
  test('allows secure persistence on supported native platforms', () {
    for (final platform in ['android', 'ios', 'linux', 'macos', 'windows']) {
      expect(
        supportsSecureForgeCredentialsForPlatform(platform),
        isTrue,
        reason: platform,
      );
    }
  });

  test('keeps web and unknown platforms fail closed', () {
    for (final platform in ['web', 'fuchsia', 'unknown']) {
      expect(
        supportsSecureForgeCredentialsForPlatform(platform),
        isFalse,
        reason: platform,
      );
    }
  });
}
