export 'forge_refresh_lock_base.dart';
import 'forge_refresh_lock_base.dart';

import 'forge_refresh_lock_stub.dart'
    if (dart.library.io) 'forge_refresh_lock_io.dart'
    as platform;

/// Creates the platform-appropriate refresh lock for [clientId].
ForgeRefreshLock createForgeRefreshLock(String clientId) =>
    platform.createForgeRefreshLock(clientId);
