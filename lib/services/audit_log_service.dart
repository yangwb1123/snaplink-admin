import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sso_admin/services/local_storage.dart';

/// A recorded admin operation for audit purposes.
class AuditEntry {
  final DateTime timestamp;
  final String method;
  final String path;
  final int statusCode;
  final String label;

  AuditEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.label,
  });

  String get methodLabel {
    switch (method) {
      case 'POST':
        return 'Create';
      case 'PUT':
        return 'Update';
      case 'DELETE':
        return 'Delete';
      case 'PATCH':
        return 'Modify';
      default:
        return method;
    }
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'method': method,
    'path': path,
    'statusCode': statusCode,
    'label': label,
  };

  static AuditEntry fromJson(Map<String, dynamic> json) => AuditEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    method: json['method'] as String,
    path: json['path'] as String,
    statusCode: json['statusCode'] as int,
    label: json['label'] as String? ?? json['path'] as String,
  );
}

/// Local audit log service with browser localStorage persistence.
///
/// Records admin operations (POST/PUT/DELETE) in memory and localStorage.
/// Keeps the last 1000 entries with search and filter support.
class AuditLogService {
  static final AuditLogService _instance = AuditLogService._();
  factory AuditLogService() => _instance;
  AuditLogService._() {
    _load();
  }

  final List<AuditEntry> _entries = [];
  static const int _maxEntries = 1000;
  static const String _storageKey = 'sso_audit_log';

  /// Debug-only ring copy surface gate (B6-1b).
  ///
  /// The localStorage ring is demoted to a debug-only recording ("ring
  /// 降级为调试记录"); this flag controls whether the timeline may render
  /// ring-scoped copy (debug marker chip + Clear action). Const-folded to
  /// `false` in release/profile — no release-reachable code can flip it
  /// (the setter is itself const-gated), so the surface is absent, never
  /// lying, in release builds.
  static bool _ringCopyEnabled = kDebugMode;

  /// True when the debug-only ring copy surface may render.
  static bool get ringCopyEnabled => _ringCopyEnabled;

  @visibleForTesting
  static set debugRingEnabled(bool value) {
    if (!kDebugMode) return; // const-folds to `return;` in release.
    _ringCopyEnabled = value;
  }

  List<AuditEntry> get entries => List.unmodifiable(_entries);

  void record(AuditEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    _save();
  }

  List<AuditEntry> search(String query) {
    if (query.isEmpty) return entries;
    final q = query.toLowerCase();
    return _entries
        .where(
          (e) =>
              e.path.toLowerCase().contains(q) ||
              e.label.toLowerCase().contains(q) ||
              e.method.toLowerCase().contains(q),
        )
        .toList();
  }

  List<AuditEntry> filterByMethod(String? method) {
    if (method == null || method == 'ALL') return entries;
    return _entries.where((e) => e.method == method).toList();
  }

  List<AuditEntry> recent(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  void clear() {
    _entries.clear();
    _save();
  }

  int get count => _entries.length;

  void _save() {
    try {
      final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());
      LocalStorage.setItem(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('audit_log persist/load error: $e');
    }
  }

  void _load() {
    try {
      final jsonStr = LocalStorage.getItem(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        _entries.addAll(
          list.map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e))),
        );
      }
    } catch (e) {
      debugPrint('audit_log persist/load error: $e');
    }
  }
}
