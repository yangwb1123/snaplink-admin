import 'package:flutter/material.dart';

class ConnectionErrorCard extends StatelessWidget {
  final String error;

  const ConnectionErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        error,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}
