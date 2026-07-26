import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

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
      csv.writeln(headers.map((h) => _escapeCsv(row[h]?.toString() ?? '')).join(','));
    }
    
    _download(csv.toString(), filename, 'text/csv;charset=utf-8');
  }

  /// Export a list of maps as a JSON file and trigger download.
  static void exportJson(List<Map<String, dynamic>> data, String filename) {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    _download(json, filename, 'application/json;charset=utf-8');
  }

  static void _download(String content, String filename, String mimeType) {
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
