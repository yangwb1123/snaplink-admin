import 'forge_native_credential_platform_stub.dart'
    if (dart.library.io) 'forge_native_credential_platform_io.dart'
    as platform;

bool get supportsSecureForgeCredentials => platform.supportsSecureCredentials;
