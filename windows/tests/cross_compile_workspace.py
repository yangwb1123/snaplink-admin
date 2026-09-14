#!/usr/bin/env python3
"""Compile native workspace code with Zig and official Flutter Windows artifacts.

This is supplemental cross-platform evidence. It does not replace the Windows
MSVC build, CTest run, or system file dialog acceptance.
"""

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", default="zig")
    parser.add_argument("--client-wrapper", type=pathlib.Path, required=True)
    parser.add_argument("--engine", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    wrapper = args.client_wrapper.resolve()
    engine = args.engine.resolve()
    output = args.output.resolve()
    windows = pathlib.Path(__file__).resolve().parents[1]
    required = [wrapper / "include/flutter/flutter_view_controller.h",
                wrapper / "core_implementations.cc", wrapper / "standard_codec.cc",
                engine / "flutter_windows.h", engine / "flutter_windows.dll.lib",
                engine / "flutter_windows.dll"]
    for path in required:
        if not path.is_file():
            parser.error(f"Missing official Flutter Windows artifact: {path}")
    output.mkdir(parents=True, exist_ok=True)
    common = [args.zig, "c++", "-target", "x86_64-windows-gnu", "-std=c++17",
              "-DNOMINMAX", "-DUNICODE", "-D_UNICODE", "-Wall", "-Wextra",
              "-Werror", "-Wno-unused-parameter", "-I" + str(wrapper / "include"),
              "-I" + str(engine), "-I" + str(windows)]
    names = ["workspace_file_contract.cpp", "workspace_file_io.cpp",
             "workspace_file_worker.cpp", "workspace_file_channel.cpp",
             "workspace_file_channel_test.cpp", "workspace_file_native_test.cpp"]
    sources = [windows / "runner" / name for name in names]
    sources += [wrapper / "standard_codec.cc", wrapper / "core_implementations.cc"]
    commands = []
    objects = []
    for source in sources + [windows / "runner/flutter_window.cpp"]:
        target = output / (source.stem + ".obj")
        command = common + ["-c", str(source), "-o", str(target)]
        commands.append(command)
        print("Compiling", source.name, flush=True)
        subprocess.run(command, check=True)
        if source in sources:
            objects.append(str(target))
    executable = output / "workspace_file_native_test.exe"
    command = common + objects + [str(engine / "flutter_windows.dll.lib"),
                                  "-o", str(executable), "-luser32", "-lole32",
                                  "-lshell32", "-luuid"]
    commands.append(command)
    subprocess.run(command, check=True)
    shutil.copy2(engine / "flutter_windows.dll", output / "flutter_windows.dll")
    version = subprocess.check_output([args.zig, "version"], text=True).strip()
    evidence_files = sources + required + [windows / "runner/flutter_window.cpp",
                                            executable]
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in evidence_files}
    (output / "cross-compile.json").write_text(json.dumps({
        "compiler": version, "target": "x86_64-windows-gnu", "commands": commands,
        "sha256": hashes, "runtime_executed": False,
    }, indent=2) + "\n", encoding="utf-8")
    print("Windows cross compilation passed; runtime acceptance remains separate.")


if __name__ == "__main__":
    main()
