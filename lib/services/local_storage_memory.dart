final Map<String, String> _memoryStore = {};

String? getItem(String key) => _memoryStore[key];

void setItem(String key, String value) {
  _memoryStore[key] = value;
}

void removeItem(String key) {
  _memoryStore.remove(key);
}

List<String> keys() => _memoryStore.keys.toList(growable: false);
