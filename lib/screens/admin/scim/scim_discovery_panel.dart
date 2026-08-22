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

  Color get _accent => adminModuleIconColor('scim-directory');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
    });
    try {
      final results = await Future.wait([
        widget.api.get('$scimBasePath/ServiceProviderConfig'),
        widget.api.get('$scimBasePath/Schemas'),
      ]);
      final schemaValues = results[1]['Resources'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _profile = ScimServiceProfile.fromJson(results[0]);
        _schemas = schemaValues
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 404 || error.status == 501) {
          _unavailable = true;
        } else {
          _error = context.tr('SCIM request failed ({status}): {error}', {
            'status': '${error.status}',
            'error': error.toString(),
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Could not load SCIM discovery.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildDiscoveryPanel(context);
}
