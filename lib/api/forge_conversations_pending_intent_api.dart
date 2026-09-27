part of 'forge_conversations_api.dart';

/// The Coordinator's pending-intent read window is intentionally smaller than
/// the general Conversation page. A pending intent is a receipt projection;
/// this client never treats it as a Run or as execution authority.
const _forgePendingIntentPageSize = 25;

class ForgePendingRunIntentCursor {
  final int submittedAtMS;
  final String intentID;

  const ForgePendingRunIntentCursor({
    required this.submittedAtMS,
    required this.intentID,
  });

  factory ForgePendingRunIntentCursor.fromJson(Object? value) {
    final json = _pendingAPIObject(value);
    _pendingAPIExactKeys(json, const {'submitted_at_ms', 'intent_id'});
    final submittedAtMS = _pendingAPINonNegativeInt(json, 'submitted_at_ms');
    final intentID = _pendingAPIExactText(json, 'intent_id');
    if (submittedAtMS > forgePendingRunIntentMaxSafeInteger ||
        !_validPendingRunIntentID(intentID)) {
      throw const FormatException('Invalid Forge pending Run-intent cursor.');
    }
    return ForgePendingRunIntentCursor(
      submittedAtMS: submittedAtMS,
      intentID: intentID,
    );
  }

  Map<String, dynamic> toJson() => {
    'submitted_at_ms': submittedAtMS,
    'intent_id': intentID,
  };
}

/// A strict owner-scoped page returned by the authenticated pending-intent
/// endpoint. The response carries metadata only; Prompt content is never
/// included by this projection.
class ForgePendingRunIntentListPage {
  final String conversationID;
  final List<ForgePendingRunIntentRecord> intents;
  final ForgePendingRunIntentCursor? nextCursor;
  final bool hasMore;

  const ForgePendingRunIntentListPage({
    required this.conversationID,
    required this.intents,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ForgePendingRunIntentListPage.fromJson(
    ForgeJson json, {
    required String requestedConversationID,
    ForgePendingRunIntentCursor? before,
    int limit = _forgePendingIntentPageSize,
  }) {
    if (limit < 1 ||
        limit > _forgePendingIntentPageSize ||
        !_validConversationRequestID(requestedConversationID)) {
      throw const FormatException(
        'Invalid Forge pending Run-intent page limit.',
      );
    }
    final hasCursor = json.containsKey('next_cursor');
    _pendingAPIExactKeys(json, {
      'conversation_id',
      'intents',
      'has_more',
      if (hasCursor) 'next_cursor',
    });
    final conversationID = _pendingAPIExactText(json, 'conversation_id');
    final hasMore = json['has_more'];
    final rawIntents = json['intents'];
    if (!_validConversationRequestID(conversationID) ||
        conversationID != requestedConversationID ||
        hasMore is! bool ||
        rawIntents is! List ||
        rawIntents.length > limit ||
        rawIntents.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge pending Run-intent page.');
    }
    final nextCursor = hasCursor
        ? ForgePendingRunIntentCursor.fromJson(json['next_cursor'])
        : null;
    if (hasMore != (nextCursor != null) ||
        (hasMore && rawIntents.isEmpty) ||
        (hasMore && rawIntents.length != limit)) {
      throw const FormatException('Invalid Forge pending Run-intent cursor.');
    }
    final intents = rawIntents
        .map(
          (value) => ForgePendingRunIntentRecord.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final seen = <String>{};
    ForgePendingRunIntentRecord? previous;
    for (final intent in intents) {
      if (!_validPendingRunIntentRecord(intent, requestedConversationID) ||
          !seen.add(intent.intentID) ||
          (previous != null && !_newerPendingRunIntent(previous, intent)) ||
          (before != null && !_olderThanPendingRunIntent(intent, before))) {
        throw const FormatException('Invalid Forge pending Run-intent order.');
      }
      previous = intent;
    }
    if (hasMore) {
      final last = intents.last;
      if (nextCursor!.submittedAtMS != last.submittedAtMS ||
          nextCursor.intentID != last.intentID) {
        throw const FormatException('Invalid Forge pending Run-intent cursor.');
      }
    }
    return ForgePendingRunIntentListPage(
      conversationID: conversationID,
      intents: List.unmodifiable(intents),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}

/// Payload-free event metadata for one pending intent. Current Platform Core
/// exposes only the initial `submitted` marker and an empty continuation page;
/// both shapes are validated explicitly so a content-bearing event cannot
/// enter the shared client surface.
class ForgePendingRunIntentTimelinePage {
  final String conversationID;
  final String intentID;
  final int afterSequence;
  final int scannedThroughSequence;
  final bool hasMore;
  final List<ForgePendingRunIntentEvent> events;

  const ForgePendingRunIntentTimelinePage({
    required this.conversationID,
    required this.intentID,
    required this.afterSequence,
    required this.scannedThroughSequence,
    required this.hasMore,
    required this.events,
  });

  factory ForgePendingRunIntentTimelinePage.fromJson(
    ForgeJson json, {
    required String requestedConversationID,
    required String requestedIntentID,
    required int requestedAfterSequence,
    int limit = _forgePendingIntentPageSize,
  }) {
    if (limit < 1 ||
        limit > _forgePendingIntentPageSize ||
        requestedAfterSequence < 0 ||
        requestedAfterSequence > forgePendingRunIntentMaxSafeInteger ||
        !_validConversationRequestID(requestedConversationID) ||
        !_validPendingRunIntentID(requestedIntentID)) {
      throw const FormatException(
        'Invalid Forge pending Run-intent timeline request.',
      );
    }
    _pendingAPIExactKeys(json, const {
      'conversation_id',
      'intent_id',
      'after_sequence',
      'scanned_through_sequence',
      'has_more',
      'events',
    });
    final conversationID = _pendingAPIExactText(json, 'conversation_id');
    final intentID = _pendingAPIExactText(json, 'intent_id');
    final afterSequence = _pendingAPINonNegativeInt(json, 'after_sequence');
    final scannedThroughSequence = _pendingAPINonNegativeInt(
      json,
      'scanned_through_sequence',
    );
    final hasMore = json['has_more'];
    final rawEvents = json['events'];
    if (conversationID != requestedConversationID ||
        intentID != requestedIntentID ||
        afterSequence != requestedAfterSequence ||
        afterSequence > forgePendingRunIntentMaxSafeInteger ||
        scannedThroughSequence > forgePendingRunIntentMaxSafeInteger ||
        scannedThroughSequence < afterSequence ||
        hasMore is! bool ||
        rawEvents is! List ||
        rawEvents.length > limit ||
        rawEvents.any((value) => value is! Map) ||
        hasMore) {
      throw const FormatException(
        'Invalid Forge pending Run-intent timeline page.',
      );
    }
    final events = rawEvents
        .map(
          (value) => ForgePendingRunIntentEvent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    if (afterSequence == 0) {
      if (events.length != 1 || scannedThroughSequence != 1) {
        throw const FormatException(
          'Invalid initial Forge pending Run-intent timeline.',
        );
      }
    } else if (events.isNotEmpty || scannedThroughSequence != afterSequence) {
      throw const FormatException(
        'Invalid continued Forge pending Run-intent timeline.',
      );
    }
    return ForgePendingRunIntentTimelinePage(
      conversationID: conversationID,
      intentID: intentID,
      afterSequence: afterSequence,
      scannedThroughSequence: scannedThroughSequence,
      hasMore: hasMore,
      events: List.unmodifiable(events),
    );
  }
}

extension ForgeConversationsApiPendingRunIntent on ForgeConversationsApi {
  /// Submits one consent-checked pending Run-intent to the private inert
  /// candidate. The receipt stores a Prompt and pending metadata only; it
  /// does not create a Run, select a device, or authorize execution.
  Future<ForgePendingRunIntentSubmission> submitPendingRunIntent({
    required String conversationID,
    required String content,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    if (content.trim().isEmpty || utf8.encode(content).length > 256 * 1024) {
      throw ArgumentError.value(content, 'content');
    }
    if (expectedVersion < 1 ||
        expectedVersion > forgePendingRunIntentMaxSafeInteger) {
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    }
    if (!_validIdempotencyKey(idempotencyKey)) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/run-intents';
    final root = await _requestJson(
      'POST',
      path,
      body: {'content': content, 'expected_version': expectedVersion},
      idempotencyKey: idempotencyKey,
      expectedStatuses: const {200, 201},
      // A candidate write must never be replayed with a rotated bearer. The
      // caller can explicitly retry with the same idempotency key after
      // reauthentication, preserving one logical submission.
      retryUnauthorized: false,
    );
    final submission = ForgePendingRunIntentSubmission.fromJson(root);
    if (submission.prompt.conversationID != conversationID ||
        submission.prompt.role != 'user' ||
        submission.prompt.content != content ||
        submission.intent.conversationID != conversationID ||
        submission.intent.promptID != submission.prompt.id ||
        submission.prompt.createdAtMS != submission.intent.submittedAtMS ||
        submission.initialEvent.sequence != 1 ||
        submission.initialEvent.type != 'submitted' ||
        submission.initialEvent.emittedAtMS !=
            submission.intent.submittedAtMS ||
        (!submission.replayed &&
            (expectedVersion >= forgePendingRunIntentMaxSafeInteger ||
                submission.intent.aggregateVersion != expectedVersion + 1))) {
      throw const FormatException(
        'Forge returned an invalid pending Run-intent submission.',
      );
    }
    return submission;
  }

  Future<ForgePendingRunIntentListPage> listPendingRunIntents({
    required String conversationID,
    ForgePendingRunIntentCursor? before,
    int limit = _forgePendingIntentPageSize,
  }) async {
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    if (limit < 1 || limit > _forgePendingIntentPageSize) {
      throw ArgumentError.value(limit, 'limit');
    }
    final boundedLimit = limit;
    if (before != null &&
        (before.submittedAtMS < 0 ||
            before.submittedAtMS > forgePendingRunIntentMaxSafeInteger ||
            !_validPendingRunIntentID(before.intentID))) {
      throw ArgumentError.value(before, 'before');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (before != null) {
      query['before_submitted_at_ms'] = before.submittedAtMS.toString();
      query['before_intent_id'] = before.intentID;
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/run-intents';
    final root = await _requestJson('GET', path, query: query);
    return ForgePendingRunIntentListPage.fromJson(
      root,
      requestedConversationID: conversationID,
      before: before,
      limit: boundedLimit,
    );
  }

  Future<ForgePendingRunIntentTimelinePage> listPendingRunIntentTimeline({
    required String conversationID,
    required String intentID,
    int afterSequence = 0,
    int limit = _forgePendingIntentPageSize,
  }) async {
    if (!_validConversationRequestID(conversationID) ||
        !_validPendingRunIntentID(intentID)) {
      throw ArgumentError.value('$conversationID/$intentID', 'intent IDs');
    }
    if (afterSequence < 0 ||
        afterSequence > forgePendingRunIntentMaxSafeInteger) {
      throw ArgumentError.value(afterSequence, 'afterSequence');
    }
    if (limit < 1 || limit > _forgePendingIntentPageSize) {
      throw ArgumentError.value(limit, 'limit');
    }
    final boundedLimit = limit;
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/run-intents/'
        '${Uri.encodeComponent(intentID)}/timeline';
    final root = await _requestJson(
      'GET',
      path,
      query: {
        'after_sequence': afterSequence.toString(),
        'limit': boundedLimit.toString(),
      },
    );
    return ForgePendingRunIntentTimelinePage.fromJson(
      root,
      requestedConversationID: conversationID,
      requestedIntentID: intentID,
      requestedAfterSequence: afterSequence,
      limit: boundedLimit,
    );
  }
}

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
