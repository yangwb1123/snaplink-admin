import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'forge_refresh_lock_base.dart';

ForgeRefreshLock createForgeRefreshLock(String clientId) {
  // Mobile applications do not support independently running desktop
  // instances of the Console. Their secure stores already provide the
  // process boundary needed by this client, so keep the lock a no-op there.
  if (Platform.operatingSystem != 'linux' &&
      Platform.operatingSystem != 'macos' &&
      Platform.operatingSystem != 'windows') {
    return const NoopForgeRefreshLock();
  }
  return _FileForgeRefreshLock(clientId);
}

final class _FileForgeRefreshLock implements ForgeRefreshLock {
  _FileForgeRefreshLock(this._clientId);

  final String _clientId;

  @override
  Future<T> synchronized<T>(Future<T> Function() action) async {
    final file = await _lockFile();
    RandomAccessFile? handle;
    var locked = false;
    try {
      // Append preserves the lock inode if another process already opened it.
      handle = await file.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      locked = true;
      return await action();
    } finally {
      if (handle != null) {
        if (locked) {
          try {
            await handle.unlock();
          } catch (_) {
            // The operation result is already determined; close the handle
            // below even if the platform rejects a redundant unlock.
          }
        }
        await handle.close();
      }
    }
  }

  Future<File> _lockFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final lockDirectory = Directory(
      _joinPath(supportDirectory.path, 'forge-refresh-locks'),
    );
    await lockDirectory.create(recursive: true);
    final digest = sha256.convert(utf8.encode(_clientId)).toString();
    return File(_joinPath(lockDirectory.path, 'client-$digest.lock'));
  }

  String _joinPath(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
    return '$parent${Platform.pathSeparator}$child';
  }
}
