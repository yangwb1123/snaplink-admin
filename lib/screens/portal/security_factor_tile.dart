import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// A single MFA factor tile showing method, label, and remove button.
class SecurityFactorTile extends StatelessWidget {
  final Map factor;
  final bool busy;
  final void Function(String id) onRemove;

  const SecurityFactorTile({
    super.key,
    required this.factor,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final id = factor['id']?.toString() ?? '';
    var meta = factor['method']?.toString() ?? '';
    if (factor['added_at'] != null) {
      final addedAt = factor['added_at'].toString();
      meta += context.tr(' · added {date}', {
        'date': addedAt.substring(0, addedAt.length < 10 ? addedAt.length : 10),
      });
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        factor['label']?.toString() ?? factor['method']?.toString() ?? '',
      ),
      subtitle: Text(meta),
      trailing: TextButton(
        onPressed: busy ? null : () => onRemove(id),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        child: Text(context.tr('Remove')),
      ),
    );
  }
}
