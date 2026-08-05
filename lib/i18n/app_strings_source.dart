import 'app_strings_source_common.dart';
import 'app_strings_source_admin_core.dart';
import 'app_strings_source_admin_dynamic.dart';
import 'app_strings_source_admin_features.dart';
import 'app_strings_source_admin_indirect.dart';
import 'app_strings_source_admin_navigation.dart';
import 'app_strings_source_admin_residency.dart';
import 'app_strings_source_commerce.dart';
import 'app_strings_source_developer.dart';
import 'app_strings_source_oidc.dart';
import 'app_strings_source_portal.dart';

/// Domain catalogs keyed by canonical English UI copy.
///
/// English is the source language, so only non-English values are stored.
/// Splitting the catalogs by product surface keeps review ownership clear and
/// every source file within the repository's size budget.
const appSourceStrings = <String, Map<String, String>>{
  'zh': <String, String>{
    ...appCommonSourceZh,
    ...appPortalSourceZh,
    ...appDeveloperSourceZh,
    ...appOidcSourceZh,
    ...appAdminCoreSourceZh,
    ...appAdminFeatureSourceZh,
    ...appAdminIndirectSourceZh,
    ...appAdminDynamicSourceZh,
    ...appAdminNavigationSourceZh,
    ...appAdminResidencySourceZh,
    ...appCommerceSourceZh,
  },
};
