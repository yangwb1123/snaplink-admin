import 'dart:io';

import 'forge_credential_platform_policy.dart';

bool get supportsSecureCredentials =>
    supportsSecureForgeCredentialsForPlatform(Platform.operatingSystem);
