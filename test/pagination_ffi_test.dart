@TestOn('vm')
library;

import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/paginated_list.dart';

/// 回归：VM 的 Expando 拒绝 dart:ffi 的 Pointer/Struct/Union 作为键，
/// 且通过 `page` 读取与写入都会抛 ArgumentError。goNext 的公共签名是
/// 无约束的 `Object? page`，历史行为（旧实现只用 identical 判重）对任何
/// 实参都不抛异常；防陈旧导航不能把原生页对象变成新的崩溃源。
///
/// 仅 VM 运行：dart:ffi Pointer 在 Web 上不可用。地址 1 从不解引用，
/// 只作为不透明身份键使用。
void main() {
  testWidgets('goNext advances an FFI Pointer page without throwing', (
    tester,
  ) async {
    final key = GlobalKey<_PaginationHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _PaginationHost(key: key)),
      ),
    );
    final host = key.currentState!;
    final pageA = Pointer<Void>.fromAddress(1);
    final pageB = Pointer<Void>.fromAddress(2);

    host.goNext('page-2', page: pageA);
    await tester.pump();
    expect(host.currentPage, 2);
    expect(host.currentPageToken, 'page-2');
    expect(host.canGoBack, isTrue);

    // 不可追踪的键不能登记来源，但同帧防重入仍按对象身份生效。
    host.goNext('page-3', page: pageA);
    await tester.pump();
    expect(host.currentPage, 2);
    expect(host.currentPageToken, 'page-2');

    // 不同的原生页对象继续正常推进。
    host.goNext('page-3', page: pageB);
    await tester.pump();
    expect(host.currentPage, 3);
    expect(host.currentPageToken, 'page-3');

    // 回退后再用同一原生对象推进：无陈旧来源可判定，保持历史无异常
    // 的宽松行为（不能抛 ArgumentError）。
    host.goPrevious();
    await tester.pump();
    expect(host.currentPage, 2);
    host.goNext('page-3', page: pageB);
    await tester.pump();
    expect(host.currentPage, 3);
    expect(host.currentPageToken, 'page-3');
  });
}

/// PaginatedListMixin 测试宿主：真实 StatefulWidget 状态以触发 setState。
class _PaginationHost extends StatefulWidget {
  const _PaginationHost({super.key});

  @override
  State<_PaginationHost> createState() => _PaginationHostState();
}

class _PaginationHostState extends State<_PaginationHost>
    with PaginatedListMixin<_PaginationHost> {
  @override
  bool? get canGoNext => true;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
