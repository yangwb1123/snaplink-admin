import 'dart:convert';

import 'package:sso_admin/services/browser_download.dart';

/// Utility for exporting data as downloadable files (CSV, JSON).
///
/// Uses browser Blob + URL APIs via the `web` package.
/// Creates a temporary download link and triggers it programmatically.
class ExportService {
  /// Export a list of maps as a CSV file and trigger download.
  static void exportCsv(List<Map<String, dynamic>> data, String filename) {
    if (data.isEmpty) return;

    final headers = data.first.keys.toList();
    final csv = StringBuffer();
    csv.writeln(headers.map((h) => _escapeCsv(h)).join(','));
    for (final row in data) {
      csv.writeln(
        headers.map((h) => _escapeCsv(row[h]?.toString() ?? '')).join(','),
      );
    }

    BrowserDownload.text(
      csv.toString(),
      filename: filename,
      contentType: 'text/csv;charset=utf-8',
    );
  }

  /// Export a list of maps as a JSON file and trigger download.
  static void exportJson(List<Map<String, dynamic>> data, String filename) {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    BrowserDownload.text(
      json,
      filename: filename,
      contentType: 'application/json;charset=utf-8',
    );
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
