import 'package:flutter/material.dart';
import '../i18n/localized_text.dart';

/// 路由到尚未加载的代码分割入口时的占位视图。
///
/// 生产首屏在 `main()` 中预加载当前入口，因此正常首屏不会经过这里；
/// 跨入口导航（原生壳路由、浏览器深链）才触发按需加载。加载期间显示
/// 进度指示器，chunk 下载失败时提供重试（文案复用现有 'Failed to load'
/// / 'Retry' i18n key，不新增未本地化文案）。
class DeferredEntryScreen extends StatefulWidget {
  /// Deferred 库的 `loadLibrary()`。
  final Future<void> Function() load;

  /// 入口库加载完成后构建真实界面。
  final Widget Function() build;

  const DeferredEntryScreen({
    super.key,
    required this.load,
    required this.build,
  });

  @override
  State<DeferredEntryScreen> createState() => _DeferredEntryScreenState();
}

class _DeferredEntryScreenState extends State<DeferredEntryScreen> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _retry() {
    setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  const LocalizedText('Failed to load'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _retry,
                    child: const LocalizedText('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.build();
      },
    );
  }
}
