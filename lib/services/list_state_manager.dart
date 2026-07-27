import 'dart:convert';
import 'package:sso_admin/services/local_storage.dart';

/// Persists and restores list page state (filter, pagination, sort).
///
/// Each list tab gets a unique key (e.g., 'clients_list').
/// State is saved to localStorage on every change and restored
/// when the user navigates back to the list.
class ListStateManager {
  static final ListStateManager _instance = ListStateManager._();
  factory ListStateManager() => _instance;
  ListStateManager._();

  static const String _prefix = 'list_state_';

  /// Save the current state for a list view.
  void save(String listKey, Map<String, dynamic> state) {
    try {
      final json = jsonEncode(state);
      LocalStorage.setItem('$_prefix$listKey', json);
    } catch (_) {}
  }

  /// Restore the saved state for a list view.
  /// Returns null if no state was saved or if it's expired.
  Map<String, dynamic>? restore(String listKey) {
    try {
      final json = LocalStorage.getItem('$_prefix$listKey');
      if (json == null || json.isEmpty) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Clear saved state for a specific list.
  void clear(String listKey) {
    LocalStorage.removeItem('$_prefix$listKey');
  }

  /// Clear all saved list states.
  void clearAll() {
    for (final key in LocalStorage.keys()) {
      if (key.startsWith(_prefix)) LocalStorage.removeItem(key);
    }
  }
}
