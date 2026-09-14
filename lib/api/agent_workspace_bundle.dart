import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// A small, immutable file bundle. Its canonical bytes are shared with Runner.
class AgentWorkspaceBundle {
  static const schema = 'pbatch.workspace.v1';
  static const maxFiles = 128;
  static const maxFileBytes = 64 * 1024;
  static const maxRawBytes = 256 * 1024;
  static const maxJsonBytes = 512 * 1024;
  static const maxHttpBytes = 576 * 1024;

  final List<Map<String, String>> files;
  final String canonicalJson;
  final String sha256;
  final int size;
  final int rawSize;

  const AgentWorkspaceBundle._(
    this.files,
    this.canonicalJson,
    this.sha256,
    this.size,
    this.rawSize,
  );

  factory AgentWorkspaceBundle.parse(String text) {
    if (text.length > maxJsonBytes || utf8.encode(text).length > maxJsonBytes) {
      throw const FormatException('Workspace JSON exceeds 512 KiB.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Invalid workspace bundle JSON.');
    }
    return AgentWorkspaceBundle.fromJson(decoded);
  }

  factory AgentWorkspaceBundle.fromJson(Object? value) {
    if (value is! Map || value.length != 2 || value['schema'] != schema) {
      throw const FormatException('Invalid workspace bundle schema.');
    }
    final source = value['files'];
    if (source is! List || source.length > maxFiles) {
      throw const FormatException('Workspace accepts at most 128 files.');
    }
    final paths = <String>{};
    final files = <Map<String, String>>[];
    var rawSize = 0;
    for (final entry in source) {
      if (entry is! Map || entry.length != 2) {
        throw const FormatException('Invalid workspace file entry.');
      }
      final path = validateAgentWorkspacePath(entry['path']);
      if (!paths.add(path)) {
        throw const FormatException('Workspace paths must be unique.');
      }
      final content = entry['content_b64'];
      if (content is! String ||
          content.length > 4 * ((maxFileBytes + 2) ~/ 3)) {
        throw const FormatException(
          'Each workspace file must fit within 64 KiB.',
        );
      }
      late final List<int> bytes;
      try {
        bytes = base64Decode(content);
      } on FormatException {
        throw const FormatException(
          'Workspace content must use canonical base64.',
        );
      }
      if (base64Encode(bytes) != content) {
        throw const FormatException(
          'Workspace content must use canonical base64.',
        );
      }
      if (bytes.length > maxFileBytes) {
        throw const FormatException(
          'Each workspace file must fit within 64 KiB.',
        );
      }
      rawSize += bytes.length;
      if (rawSize > maxRawBytes) {
        throw const FormatException('Workspace files exceed 256 KiB in total.');
      }
      files.add(Map.unmodifiable({'content_b64': content, 'path': path}));
    }
    validateAgentWorkspacePathSet(paths.toList());
    files.sort((a, b) => compareWorkspacePaths(a['path']!, b['path']!));
    final canonical = jsonEncode({'files': files, 'schema': schema});
    final bytes = utf8.encode(canonical);
    if (bytes.length > maxJsonBytes) {
      throw const FormatException('Workspace JSON exceeds 512 KiB.');
    }
    return AgentWorkspaceBundle._(
      List.unmodifiable(files),
      canonical,
      crypto.sha256.convert(bytes).toString(),
      bytes.length,
      rawSize,
    );
  }

  Map<String, dynamic> toJson() => {'files': files, 'schema': schema};
}

String validateAgentWorkspacePath(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      !_validUnicode(value) ||
      utf8.encode(value).length > 512 ||
      value.startsWith('/') ||
      value.contains('\\') ||
      RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value)) {
    throw const FormatException(
      'Workspace paths must be explicit relative POSIX file paths.',
    );
  }
  final reserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\..*)?$',
    caseSensitive: false,
  );
  for (final segment in value.split('/')) {
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        utf8.encode(segment).length > 255 ||
        segment.endsWith('.') ||
        segment.endsWith(' ') ||
        RegExp(r'[<>:"|?*]').hasMatch(segment) ||
        reserved.hasMatch(segment)) {
      throw const FormatException(
        'Workspace paths must be explicit relative POSIX file paths.',
      );
    }
  }
  // NFC and full Unicode casefold checks remain authoritative on the server.
  return value;
}

void validateAgentWorkspacePathSet(List<String> paths) {
  final folded = paths.map((path) => path.toLowerCase()).toSet();
  if (folded.length != paths.length) {
    throw const FormatException('Workspace paths must be unique.');
  }
  for (final path in folded) {
    final parts = path.split('/');
    for (var index = 1; index < parts.length; index++) {
      if (folded.contains(parts.take(index).join('/'))) {
        throw const FormatException(
          'Workspace files cannot also be parent directories.',
        );
      }
    }
  }
}

int compareWorkspacePaths(String a, String b) {
  final left = a.runes.iterator;
  final right = b.runes.iterator;
  while (left.moveNext()) {
    if (!right.moveNext()) return 1;
    final difference = left.current.compareTo(right.current);
    if (difference != 0) return difference;
  }
  return right.moveNext() ? -1 : 0;
}

bool _validUnicode(String value) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xd800 && unit < 0xdc00) {
      if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
        return false;
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}
