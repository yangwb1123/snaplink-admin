import 'shortcut_platform_stub.dart'
    if (dart.library.js_interop) 'shortcut_platform_web.dart'
    as platform;

void Function() listen(
  void Function(String key, bool controlPressed, void Function() preventDefault)
  listener,
) => platform.listen(listener);
