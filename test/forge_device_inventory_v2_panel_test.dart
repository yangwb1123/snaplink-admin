import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/screens/forge/forge_device_inventory_v2_panel.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_INVENTORY_V2_FIXTURE'];

  testWidgets(
    'renders the v2 persisted observation without controls',
    (tester) async {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final page = ForgeDeviceInventoryPageV2.fromJson(root);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForgeDeviceInventoryV2Panel(page: page),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('forge-device-inventory-v2-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-inventory-v2-device-a-runner-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-inventory-v2-device-b-runner-b')),
        findsOneWidget,
      );
      expect(find.textContaining('revision 1'), findsOneWidget);
      expect(find.textContaining('generation 1'), findsOneWidget);
      expect(find.textContaining('heartbeat 1'), findsOneWidget);
      expect(find.textContaining('reservation reserved'), findsOneWidget);
      expect(find.textContaining('GPU gpu-a'), findsOneWidget);
      expect(find.textContaining('GPU gpu-b'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    },
    skip: fixturePath == null,
  );
}
