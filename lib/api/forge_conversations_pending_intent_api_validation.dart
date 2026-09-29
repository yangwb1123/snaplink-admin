part of 'forge_conversations_api.dart';

bool _validPendingRunIntentRecord(
  ForgePendingRunIntentRecord intent,
  String conversationID,
) =>
    intent.conversationID == conversationID &&
    _validPendingRunIntentID(intent.intentID) &&
    _validPendingRunIntentID(intent.promptID) &&
    _validPendingRunIntentID(intent.projectID) &&
    _validPendingRunIntentID(intent.profileID) &&
    intent.submittedAtMS <= forgePendingRunIntentMaxSafeInteger &&
    intent.aggregateVersion > 0 &&
    intent.aggregateVersion <= forgePendingRunIntentMaxSafeInteger &&
    intent.latestSequence == 1 &&
    intent.status == 'pending';

bool _newerPendingRunIntent(
  ForgePendingRunIntentRecord left,
  ForgePendingRunIntentRecord right,
) =>
    left.submittedAtMS > right.submittedAtMS ||
    (left.submittedAtMS == right.submittedAtMS &&
        _comparePendingIntentIDs(left.intentID, right.intentID) > 0);

bool _olderThanPendingRunIntent(
  ForgePendingRunIntentRecord intent,
  ForgePendingRunIntentCursor cursor,
) =>
    intent.submittedAtMS < cursor.submittedAtMS ||
    (intent.submittedAtMS == cursor.submittedAtMS &&
        _comparePendingIntentIDs(intent.intentID, cursor.intentID) < 0);

Map<String, dynamic> _pendingAPIObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge pending Run-intent response.');
  }
  return Map<String, dynamic>.from(value);
}

void _pendingAPIExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length || !json.keys.every(expected.contains)) {
    throw const FormatException(
      'Forge returned unexpected pending Run-intent fields.',
    );
  }
}

String _pendingAPIExactText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid Forge pending Run-intent field: $key.');
  }
  return value;
}

int _pendingAPINonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Invalid Forge pending Run-intent field: $key.');
  }
  return value;
}

int _comparePendingIntentIDs(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  final sharedLength = leftBytes.length < rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < sharedLength; index++) {
    final comparison = leftBytes[index].compareTo(rightBytes[index]);
    if (comparison != 0) return comparison;
  }
  return leftBytes.length.compareTo(rightBytes.length);
}

bool _validPendingRunIntentID(String value) =>
    _validRunRequestID(value) && !value.contains('/');
