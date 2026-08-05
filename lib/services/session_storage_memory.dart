final _values = <String, String>{};

String? getItem(String key) => _values[key];

void setItem(String key, String value) => _values[key] = value;

void removeItem(String key) => _values.remove(key);
