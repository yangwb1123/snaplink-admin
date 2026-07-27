import 'connectivity_platform_stub.dart'
    if (dart.library.js_interop) 'connectivity_platform_web.dart'
    as platform;

bool get isOnline => platform.isOnline;

void Function() listen(void Function(bool isOnline) listener) =>
    platform.listen(listener);
