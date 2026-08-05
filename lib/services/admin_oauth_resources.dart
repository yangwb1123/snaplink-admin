/// OAuth resource indicators requested by the Admin Console.
///
/// Flutter web configuration is immutable after compilation, so deployments
/// set [environmentName] with `--dart-define` while building the bundle.
abstract final class AdminOAuthResources {
  static const environmentName = 'SNAPLINK_ADMIN_OAUTH_RESOURCES';
  static const defaultValue = 'billing-api,stripe-adapter-api';

  static const _configured = String.fromEnvironment(
    environmentName,
    defaultValue: defaultValue,
  );

  static List<String> get values => parse(_configured);

  static List<String> parse(String configured) {
    final resources = <String>[];
    final seen = <String>{};
    for (final raw in configured.split(',')) {
      final resource = raw.trim();
      if (resource.isEmpty) continue;
      if (RegExp(r'[\u0000-\u0020\u007f]').hasMatch(resource)) {
        throw FormatException('Invalid Admin OAuth resource: $resource');
      }
      if (seen.add(resource)) resources.add(resource);
    }
    return List.unmodifiable(resources);
  }
}
