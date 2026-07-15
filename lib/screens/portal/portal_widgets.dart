import 'package:flutter/material.dart';

/// Inline success/error banner, the Flutter equivalent of app.js's
/// `showMsg(el, text, ok)` (`<div class="msg err|ok">`) — green/red text,
/// hidden entirely (renders nothing) once there is no message to show.
class MessageBanner extends StatelessWidget {
  final String? text;
  final bool ok;
  const MessageBanner(this.text, {super.key, this.ok = false});

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        t,
        style: TextStyle(color: ok ? Colors.greenAccent : Colors.redAccent),
      ),
    );
  }
}

/// Muted placeholder text for an empty list — mirrors app.js's
/// `<div class="empty">…</div>`.
class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

/// A labelled key/value line, the Flutter equivalent of app.js's
/// `<div class="kv"><span class="k">label</span><span>value</span></div>`
/// used on the profile summary.
class KvRow extends StatelessWidget {
  final String label;
  final String value;
  const KvRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(value),
        ],
      ),
    );
  }
}

/// Section card wrapper matching the established dark-theme look (relies on
/// the app-wide ThemeData: Color(0xFF1E293B) card surface via CardTheme,
/// brand Color(0xFF6366F1) via ColorScheme) — every portal section renders
/// as one of these, same as app.js's `<div class="card">`.
class PortalCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const PortalCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
