import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import '../admin_module_groups.dart';
import 'scim_browser_widgets.dart';
import 'scim_models.dart';

part 'scim_discovery_panel_view.dart';

class ScimDiscoveryPanel extends StatefulWidget {
  final SnaplinkAdminApi api;

  const ScimDiscoveryPanel({super.key, required this.api});

  @override
  State<ScimDiscoveryPanel> createState() => _ScimDiscoveryPanelState();
}

class _ScimDiscoveryPanelState extends State<ScimDiscoveryPanel> {
  ScimServiceProfile? _profile;
  List<Map<String, dynamic>> _schemas = const [];
  String? _error;
  bool _loading = false;
  bool _unavailable = false;
  int _reqSeq = 0;

  Color get _accent => adminModuleIconColor('scim-directory');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ScimDiscoveryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _profile = null;
      _schemas = const [];
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
      _schemas = const [];
    });
    final results = await Future.wait([
      for (final source in const ['ServiceProviderConfig', 'Schemas'])
        _read(source),
    ]);
    if (!mounted || seq != _reqSeq) return;
    final errors = <String>[];
    setState(() {
      for (final result in results) {
        final source = result.source;
        try {
          if (result.error case final Object error) throw error;
          if (source == 'ServiceProviderConfig') {
            _profile = ScimServiceProfile.fromJson(result.data!);
          } else {
            _schemas = ScimListPage.fromJson(result.data!).resources;
          }
        } catch (error) {
          if (source == 'ServiceProviderConfig' &&
              error is SnaplinkAdminApiError &&
              (error.status == 404 || error.status == 501)) {
            _unavailable = true;
          } else {
            final message = error is SnaplinkAdminApiError
                ? context.tr('SCIM request failed ({status}): {error}', {
                    'status': '${error.status}',
                    'error': error.toString(),
                  })
                : error.toString();
            errors.add('$source: $message');
          }
        }
      }
      _error = errors.isEmpty ? null : errors.join('\n');
      _loading = false;
    });
  }

  Future<({String source, Map<String, dynamic>? data, Object? error})> _read(
    String source,
  ) async {
    try {
      final data = await widget.api.get(
        '$scimBasePath/$source',
        forceRefresh: true,
      );
      return (source: source, data: data, error: null);
    } catch (error) {
      return (source: source, data: null, error: error);
    }
  }

  @override
  Widget build(BuildContext context) => _buildDiscoveryPanel(context);
}
