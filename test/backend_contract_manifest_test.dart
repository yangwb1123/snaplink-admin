@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend contract manifest covers every documented blocker', () {
    final file = File('docs/backend-contracts.json');
    expect(file.existsSync(), isTrue);

    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(document['version'], 1);
    final contracts = (document['contracts'] as List).cast<Map>();
    expect(contracts, hasLength(22));

    final ids = contracts.map((contract) => contract['id']).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      ids,
      List.generate(
        22,
        (index) => 'BC-${(index + 1).toString().padLeft(3, '0')}',
      ),
    );

    for (final contract in contracts) {
      expect(
        contract['title'],
        isA<String>().having((v) => v.trim(), 'title', isNotEmpty),
      );
      expect(
        contract['frontend_mitigation'],
        isA<String>().having((v) => v.trim(), 'mitigation', isNotEmpty),
      );
      expect(
        contract['acceptance'],
        isA<List>().having((v) => v, 'acceptance criteria', isNotEmpty),
      );
    }
    final resolved = contracts
        .where((contract) => contract['status'] == 'resolved')
        .map((contract) => contract['id'])
        .toSet();
    expect(resolved, ids);
    expect(
      contracts
          .where((contract) => contract['status'] == 'blocked')
          .map((contract) => contract['id']),
      isEmpty,
    );
  });
}
