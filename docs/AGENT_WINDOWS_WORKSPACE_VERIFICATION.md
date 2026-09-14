# Windows workspace native verification

The 2026-09-13 local follow-up compiles the Windows host against real Win32
headers and runs the native test executable under Wine. It supplements the
Windows CI build; it is not a Microsoft Visual C++ build or Windows device
acceptance.

## Executed checks

`windows/tests/cross_compile_workspace.py` compiled the production contract,
I/O, worker, COM channel, and `FlutterWindow` translation units with Zig
`0.16.0-dev.2565+684032671`, target `x86_64-windows-gnu`, C++17, and
`-Wall -Wextra -Werror -Wno-unused-parameter`. It also compiled the native tests
and the official Flutter `standard_codec.cc` and `core_implementations.cc`.
The executable linked to the official `flutter_windows.dll.lib` and loaded the
matching Flutter DLL; no Flutter or Win32 API implementation was stubbed.

Both test groups passed under Wine 9.0 in an isolated `/tmp` prefix and Xvfb:

- Argument/I/O/worker tests: strict map types and filenames, 512 KiB boundary,
  byte preservation, shorter-file truncation, empty files, directory and `NUL`
  device refusal, oversized/cancelled saves preserving the previous file,
  asynchronous read/write, pre-start cancellation with owner release, and a real
  message-only HWND receiving a pointer-free completion exactly once.
- Standard method codec/channel tests: capability reply, unknown method,
  invalid/oversized argument error envelopes, unavailable COM apartment with
  repeatable error recovery, idle wakeup handling, and channel unregistration
  on idle destruction. Replies are decoded with Flutter's actual codec.

Successful pick/save replies through the complete channel, busy responses,
destruction during a dialog or active I/O, user rename/overwrite interaction,
reparse-point behavior, and real Windows filesystem drivers were **not** tested
by this run. The direct I/O/worker byte tests do not establish those behaviors.
No Flutter UI or full Windows application was executed. `FlutterWindow` was
compiled as an object; full application linking remains a Windows CI check.

## Exact dependencies

This run used Flutter engine `460e8e85b1945c78f9430c7f3a6d3756474d0230`, from the
locally available Flutter `3.48.0-0.5.pre` SDK, independently of Dart package
resolution. The C++ wrapper, public headers, import library, and DLL came from
the same engine's official artifacts:

- [Windows debug engine archive](https://storage.googleapis.com/flutter_infra_release/flutter/460e8e85b1945c78f9430c7f3a6d3756474d0230/windows-x64-debug/windows-x64-flutter.zip)
- [Windows C++ client wrapper](https://storage.googleapis.com/flutter_infra_release/flutter/460e8e85b1945c78f9430c7f3a6d3756474d0230/windows-x64/flutter-cpp-client-wrapper.zip)

| Artifact | SHA-256 |
| --- | --- |
| `windows-x64-flutter.zip` | `1e813ed21c4549946fd7ed6c3530241fb016dbca044efe28fa45d96f66951eee` |
| `flutter-cpp-client-wrapper.zip` | `8121fc5401f8e988ea6a9149fcf50f2cf65ca691dd7bfb5c8c23d2ba4fc41f61` |
| `flutter_windows.dll` | `6908ede1917fd8bc2625c24c4f8e2ab3a4fe960522c33f63c72de803d59085c2` |
| `flutter_windows.dll.lib` | `638b20f16965596291df6a494667867637dc2f03801406a9285f28c8b4337ed0` |

Wine was extracted from Ubuntu Noble's signed APT repository packages
`wine64`/`libwine` version `9.0~repack-4build3` and `libz-mingw-w64`
`1.3.1+dfsg-1`; no system packages were installed. The extracted wineserver
launcher was pointed at its sibling `/tmp` binary, and the package's x64
`zlib1.dll` was copied into the isolated prefix's `system32`. The user's Wine
configuration and desktop session were not used.

## Stable Flutter 3.47.4 revalidation

The same day, the unmodified native sources and script from commit
`b707b5d41ebf4e022a07eae079fbe29686e390cd` were rebuilt against the official
Flutter **3.47.4** Windows artifacts. Its framework revision
`9584c6713b324636289d067944a46fd6b49df14b` pins engine
`06a2e2a110089dff50fe635cffd2a61e1b24fbcd` in the
[official engine version file](https://raw.githubusercontent.com/flutter/flutter/9584c6713b324636289d067944a46fd6b49df14b/bin/internal/engine.version).

All nine translation units compiled with the same warnings-as-errors flags.
The native argument/I/O/worker and standard-codec/channel test groups both
passed under the same isolated Wine/Xvfb environment, loading the matching
stable Flutter DLL. The wrapper, public headers, DLL, and import library all
came from this stable engine; prerelease headers and libraries were not mixed
into the second build.

- [Stable Windows debug engine archive](https://storage.googleapis.com/flutter_infra_release/flutter/06a2e2a110089dff50fe635cffd2a61e1b24fbcd/windows-x64-debug/windows-x64-flutter.zip)
- [Stable Windows C++ client wrapper](https://storage.googleapis.com/flutter_infra_release/flutter/06a2e2a110089dff50fe635cffd2a61e1b24fbcd/windows-x64/flutter-cpp-client-wrapper.zip)

| Stable artifact | SHA-256 |
| --- | --- |
| `windows-x64-flutter.zip` | `dc6a604bbdf503ecc20da68e47a37c7c7433cce03cf9cfc66c67a51c18a7492d` |
| `flutter-cpp-client-wrapper.zip` | `8a012b68c2c439c036bfb1b54278da53aec3891fd4312a4e32ab6690d7724e7b` |
| `flutter_windows.dll` | `9d0a838d3b5d07a0b71d895a5c28ea7512a2a2a8548dde86524290124b7510c4` |
| `flutter_windows.dll.lib` | `c1509f97c316115e005cf92115375058501d3c40c9fb85d7724d41489f4ba04d` |
| Native test executable | `2ba132644d6b73a317a5f408779908b5a39a264ddcb0f024540ec1e2ae49ce50` |

The stable artifacts and evidence are preserved separately under
`/tmp/hub-native-acceptance/windows-cross-stable/`: `cross-compile.log`,
`wine-tests.log`, and `final/cross-compile.json`. The earlier prerelease run
remains under `windows-cross/`. The stable run has the same coverage limits
listed above: it does not establish MSVC, full application, physical Windows,
system dialog, or pending-operation lifecycle acceptance. These C++ checks do
not exercise Dart package resolution or claim a lockfile-enforced Flutter build.

## Reproduction

Download and extract the two matching engine archives into `ENGINE_DIR`, then
run from the repository root:

```sh
python3 windows/tests/cross_compile_workspace.py \
  --client-wrapper "$ENGINE_DIR/cpp_client_wrapper" \
  --engine "$ENGINE_DIR" --output /tmp/workspace-windows-cross
WINEPREFIX=/tmp/workspace-windows-prefix WINEARCH=win64 \
  xvfb-run -a wine /tmp/workspace-windows-cross/workspace_file_native_test.exe
```

The script emits `cross-compile.json` with exact compiler commands and SHA-256
digests. Compilation and runtime execution are separate results. The original
logs and executable are retained under
`/tmp/hub-native-acceptance/windows-cross/`; the runtime prefix is
`/tmp/hub-native-acceptance/wine-prefix-v2`.

Windows CI continues to build with the official Flutter Windows toolchain:

```powershell
flutter build windows --debug --no-pub
cmake --build build/windows/x64 --config Debug --target workspace_file_native_test
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
```

The CMake test target now includes the production COM channel and both new and
existing tests. The local cross compilation does not claim that this Windows
CI run or the system file dialog acceptance has occurred.
