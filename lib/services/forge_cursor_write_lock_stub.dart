Future<void> withLock(String key, Future<void> Function() write) => write();
