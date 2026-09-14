# Desktop workspace JSON files

The Linux and Windows runners register the native workspace file channel used by
the shared Console UI. Files contain the existing `pbatch.workspace.v1` JSON
bundle; saving does not extract or merge files into a project directory.

## Native boundary

Both hosts implement `site.ywbsd.sso/agent_workspace_files` with version 1
capabilities. `pickJson` accepts only `maxBytes`, an integer from 1 to 524288.
`saveJson` accepts only a validated suggested filename and a byte array of at
most 524288 bytes. Suggested filenames fully match
`workspace-[A-Za-z0-9_-]{1,96}.json`; users can rename the file in the system
dialog. Paths are obtained only from the dialog, never from Dart arguments.

Reads loop across short reads and stop after at most the requested limit plus
one byte. Oversized input returns `too_large`. Input decoding, JSON schema and
Hub digest checks remain in Dart. Cancellation returns null for picking and
false for saving. Save success is acknowledged after writing, flushing and
closing. Errors contain fixed codes and text, without the selected path or file
contents. A second operation returns `busy` while a dialog or I/O is active.

Linux uses `GtkFileChooserNative`, local filesystem selections, and `GTask`
workers. The opened input descriptor must be a regular file; FIFO and other
special handles are refused. Save uses replacement of a regular file, with
private creation permissions and overwrite confirmation in GTK. Closing the
window disconnects the channel and dialog, invalidates worker completion and
requests cancellation without waiting on filesystem I/O. A stalled filesystem
call therefore does not hold the GTK thread. Background buffers are released
when their worker exits; cancellation cannot force every kernel filesystem call
to return immediately.

Windows uses COM file dialogs, regular disk handles, and independently bounded
Win32 reads and writes. Reparse points and special handles are refused. The
window owns the channel and unregisters it before destroying the Flutter engine.
Filesystem operations run on a worker containing only the selected path and
bounded bytes. Completion is consumed on the platform thread through a Windows
message carrying no pointer. Closing invalidates the response, requests
`CancelSynchronousIo`, and releases the UI without joining the worker. A driver
may finish cancellation later; that worker cannot reply to a closed or newer
request. See Microsoft's
[cancellation contract](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelsynchronousio).

## Validation

The Linux debug application was compiled locally with Flutter
`3.48.0-0.5.pre` and Dart `3.12.0-168.0.dev`. The seven GTK/C++ test groups exercise
strict arguments, filenames, size boundaries, byte preservation, truncation,
FIFO refusal, cancelled I/O, standard codec responses, dialog cancellation,
busy responses, asynchronous read/save, user rename, pending destruction, stale
completion and production chooser cleanup. The GTK tests run on an isolated
Xvfb display; they do not require a Hub login or network service.

```sh
flutter build linux --debug --no-pub
cmake --build build/linux/x64/debug --target workspace_file_native_test
xvfb-run -a build/linux/x64/debug/workspace_file_native_test
```

Windows host translation units now cross-compile against Zig's Win32 headers
and official Flutter Windows artifacts. Native argument/I/O/worker tests and
the standard-codec channel error-path tests pass under Wine. This is separate
from MSVC, real Windows, and system file dialog acceptance; exact coverage,
artifact versions, and remaining gaps are recorded in
[Windows verification](AGENT_WINDOWS_WORKSPACE_VERIFICATION.md). Windows CI
can build and run the same test target with:

```powershell
flutter build windows --debug --no-pub
cmake --build build/windows/x64 --config Debug --target workspace_file_native_test
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
```

The available Flutter prerelease SDK resolves five packages below the versions
in the repository lockfile (`intl`, `matcher`, `meta`, `test_api`, `vector_math`).
The local checks used its offline resolution and `--no-pub`; they are not a
lockfile-enforced build. The repository lockfile was left unchanged. Platform
CI remains required before claiming Windows release readiness.
