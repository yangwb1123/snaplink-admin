import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A section wrapper used in governance views.
class GovernanceSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const GovernanceSection({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ...children,
    ]),
  );
}

/// A card wrapper used in governance views.
class GovernanceCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const GovernanceCard({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...children,
      ]),
    ),
  );
}

/// A card displaying JSON data with a copy button.
class GovernanceJsonCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  const GovernanceJsonCard({super.key, required this.title, required this.data});
  @override
  Widget build(BuildContext context) {
    final jsonText = const JsonEncoder.withIndent('  ').convert(data);
    return GovernanceCard(title: title, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(child: SelectableText(jsonText, style: _code)),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: jsonText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copied.')),
              );
            }
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy JSON'),
        ),
      ),
    ]);
  }
}

/// Error banner displayed in governance views.
class GovernanceErrorBanner extends StatelessWidget {
  final String error;
  const GovernanceErrorBanner({super.key, required this.error});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(error, style: const TextStyle(color: Colors.redAccent)),
  );
}

/// Audit results card with event list and copy button.
class GovernanceAuditResults extends StatelessWidget {
  final Map<String, dynamic> result;
  final Map<String, dynamic>? facets;
  const GovernanceAuditResults({super.key, required this.result, this.facets});
  @override
  Widget build(BuildContext context) {
    final rawEvents = result['events'];
    final events = rawEvents is List ? rawEvents.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const <Map<String, dynamic>>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GovernanceCard(title: 'Audit results (${result['count'] ?? events.length})', children: [
        if (events.isEmpty) const Text('No matching events.'),
        for (final event in events.take(20))
          ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            title: Text(event['type']?.toString() ?? event['id']?.toString() ?? 'Event'),
            subtitle: Text('${event['timestamp'] ?? event['created_at'] ?? ''} ${event['outcome'] ?? ''}'.trim()),
          ),
        if (events.length > 20) Text('${events.length - 20} more results present.'),
      ]),
      if (facets != null) ...[const SizedBox(height: 4), GovernanceJsonCard(title: 'Facets', data: facets!)],
    ]);
  }
}

const _code = TextStyle(fontFamily: 'monospace', fontSize: 12);
