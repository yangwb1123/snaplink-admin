import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/forge_conversations_api_origin.dart';

void main() {
  test('normalizes safe HTTPS and loopback origins', () {
    expect(
      ForgeConversationsApiOrigin.normalizeOrigin(' https://forge.example/ '),
      'https://forge.example',
    );
    expect(
      ForgeConversationsApiOrigin.normalizeOrigin('http://127.0.0.1:8080'),
      'http://127.0.0.1:8080',
    );
  });

  test(
    'rejects credentials, paths, queries, fragments, and non-loopback HTTP',
    () {
      for (final value in [
        'https://user:secret@forge.example',
        'https://forge.example/api',
        'https://forge.example?token=value',
        'https://forge.example/#fragment',
        'http://forge.example',
      ]) {
        expect(
          () => ForgeConversationsApiOrigin.normalizeOrigin(value),
          throwsFormatException,
        );
      }
    },
  );
}
