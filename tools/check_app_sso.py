#!/usr/bin/env python3
"""Offline declaration diagnostic. Usage/schema: docs/BROWSER_SSO.md.

Only --input /absolute/normalized/file.json (or --help) is supported. There is
no execution mode, URL parser, environment configuration, or referenced file.
"""

import os
import stat
import sys

# A direct invocation must not create project bytecode/cache files.
if __name__ == '__main__':
    sys.dont_write_bytecode = True

import json

if __package__:
    from .app_sso import (MAX_INPUT_BYTES, DeclarationError, decode_declarations,
                          diagnose, input_report)
else:
    from app_sso import (MAX_INPUT_BYTES, DeclarationError, decode_declarations,
                         diagnose, input_report)


class InputFileError(ValueError):
    def __init__(self, kind):
        self.kind = kind
        super().__init__('input_file_rejected')


def _components(path):
    if (type(path) is not str or not 1 < len(path) <= 4096 or not path.startswith('/')
            or any(ord(char) < 32 or ord(char) == 127 for char in path)):
        raise InputFileError('unsafe_file')
    components = path.split('/')[1:]
    if any(part in ('', '.', '..') for part in components):
        raise InputFileError('unsafe_file')
    return components


def _signature(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_gid,
            info.st_nlink, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def read_input_file(path):
    """Read one bounded regular file via anchored, no-symlink descriptors.

    No path expansion, directory listing, link following, fallback or retry.
    O_NONBLOCK avoids waiting on a FIFO before the regular-file check.
    """
    parts = _components(path)
    try:
        directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
        directory = os.open('/', directory_flags)
        try:
            for part in parts[:-1]:
                child = os.open(part, directory_flags, dir_fd=directory)
                os.close(directory)
                directory = child
            descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK |
                                 os.O_CLOEXEC, dir_fd=directory)
        finally:
            os.close(directory)
        try:
            before = os.fstat(descriptor)
            if (not stat.S_ISREG(before.st_mode) or before.st_nlink != 1
                    or before.st_uid not in (0, os.getuid()) or before.st_mode & 0o022
                    or not 0 <= before.st_size <= MAX_INPUT_BYTES):
                raise InputFileError('unsafe_file')
            data = bytearray()
            while len(data) <= MAX_INPUT_BYTES:
                chunk = os.read(descriptor, min(4096, MAX_INPUT_BYTES + 1 - len(data)))
                if not chunk:
                    break
                data.extend(chunk)
            after = os.fstat(descriptor)
            if (len(data) > MAX_INPUT_BYTES or len(data) != before.st_size
                    or _signature(before) != _signature(after)):
                raise InputFileError('unsafe_file')
            return bytes(data)
        finally:
            os.close(descriptor)
    except OSError:
        raise InputFileError('unreadable_file') from None


def _run(args):
    if not args:
        return input_report('missing_file'), 2
    if args in (['--help'], ['-h']):
        return input_report('help'), 0
    if len(args) != 2 or args[0] != '--input':
        return input_report('arguments'), 2
    if args[1] == '':
        return input_report('missing_file'), 2
    declarations = decode_declarations(read_input_file(args[1]))
    report = diagnose(declarations)
    return report, 2 if report['assessment'] == 'missing_inputs' else 0


def main(argv=None):
    # Deliberately no argparse defaults/errors: they can echo arbitrary argv.
    try:
        report, exit_code = _run(sys.argv[1:] if argv is None else argv)
    except InputFileError as error:
        report, exit_code = input_report(error.kind), 2
    except DeclarationError:
        report, exit_code = input_report('declarations'), 2
    except KeyboardInterrupt:
        report, exit_code = input_report('interrupted'), 130
    except Exception:
        report, exit_code = input_report('internal'), 3
    try:
        print(json.dumps(report, sort_keys=True, separators=(',', ':')))
    except OSError:
        return 3
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
