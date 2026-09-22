/// Serializes a Forge refresh-token exchange for one OAuth client.
///
/// The native desktop implementation uses a lock file shared by all
/// processes of this application. Web and platforms without a supported
/// inter-process primitive use a no-op implementation because their session
/// storage is process/tab scoped.
abstract interface class ForgeRefreshLock {
  Future<T> synchronized<T>(Future<T> Function() action);
}

/// A lock implementation for callers that do not need cross-process
/// coordination, including tests and web/mobile session stores.
final class NoopForgeRefreshLock implements ForgeRefreshLock {
  const NoopForgeRefreshLock();

  @override
  Future<T> synchronized<T>(Future<T> Function() action) => action();
}
