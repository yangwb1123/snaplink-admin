enum ProductEntry { login, setup, portal, developer, deviceVerification, admin }

bool _matchesPath(String path, String entryPath) =>
    path == entryPath || path.startsWith('$entryPath/');

/// Classifies a browser path without accepting lookalike prefixes such as
/// `/administrator` or `/portal-evil`.
ProductEntry productEntryForPath(String path) {
  if (_matchesPath(path, '/setup')) return ProductEntry.setup;
  if (_matchesPath(path, '/portal')) return ProductEntry.portal;
  if (_matchesPath(path, '/developer')) return ProductEntry.developer;
  if (_matchesPath(path, '/device/verify')) {
    return ProductEntry.deviceVerification;
  }
  if (_matchesPath(path, '/admin')) return ProductEntry.admin;
  return ProductEntry.login;
}
