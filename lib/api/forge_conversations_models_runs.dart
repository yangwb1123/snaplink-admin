part of 'forge_conversations_models.dart';

class ForgeRunCursor {
  final int createdAtMS;
  final String runID;

  const ForgeRunCursor({required this.createdAtMS, required this.runID});

  factory ForgeRunCursor.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {'created_at_ms', 'run_id'});
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    final runID = _requiredExactText(json, 'run_id');
    if (createdAtMS > _maxSafeForgeCursor || !_validFeedID(runID)) {
      throw const FormatException('Invalid Forge run cursor.');
    }
    return ForgeRunCursor(createdAtMS: createdAtMS, runID: runID);
  }
}

class ForgeConversationRun {
  final String runID;
  final String promptID;
  final int createdAtMS;
  final int latestSequence;
  final String status;

  const ForgeConversationRun({
    required this.runID,
    required this.promptID,
    required this.createdAtMS,
    required this.latestSequence,
    required this.status,
  });

  factory ForgeConversationRun.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'run_id',
      'prompt_id',
      'created_at_ms',
      'latest_sequence',
      'status',
    });
    final runID = _requiredExactText(json, 'run_id');
    final promptID = _requiredExactText(json, 'prompt_id');
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    final latestSequence = _requiredNonNegativeInt(json, 'latest_sequence');
    final status = _requiredExactText(json, 'status');
    if (!_validFeedID(runID) ||
        !_validFeedID(promptID) ||
        createdAtMS > _maxSafeForgeCursor ||
        latestSequence < 1 ||
        latestSequence > _maxSafeForgeCursor ||
        !_forgeRunStatuses.contains(status)) {
      throw const FormatException('Invalid Forge run summary.');
    }
    return ForgeConversationRun(
      runID: runID,
      promptID: promptID,
      createdAtMS: createdAtMS,
      latestSequence: latestSequence,
      status: status,
    );
  }
}

class ForgeConversationRunPage {
  final String conversationID;
  final List<ForgeConversationRun> runs;
  final ForgeRunCursor? nextCursor;
  final bool hasMore;

  const ForgeConversationRunPage({
    required this.conversationID,
    required this.runs,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ForgeConversationRunPage.fromJson(
    ForgeJson json, {
    required String requestedConversationID,
    ForgeRunCursor? before,
    int limit = _maxForgeRunPageSize,
  }) {
    if (limit < 1 || limit > _maxForgeRunPageSize) {
      throw const FormatException('Invalid Forge run page limit.');
    }
    final hasCursor = json.containsKey('next_cursor');
    _requireExactKeys(json, {
      'conversation_id',
      'runs',
      'has_more',
      if (hasCursor) 'next_cursor',
    });
    final conversationID = _requiredExactText(json, 'conversation_id');
    final rawRuns = json['runs'];
    if (rawRuns is! List || rawRuns.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge run page.');
    }
    final hasMore = json['has_more'];
    if (hasMore is! bool) {
      throw const FormatException('Invalid Forge run page.');
    }
    final nextCursor = hasCursor
        ? ForgeRunCursor.fromJson(_asObject(json['next_cursor']))
        : null;
    final page = ForgeConversationRunPage(
      conversationID: conversationID,
      runs: List.unmodifiable(
        rawRuns.map(
          (value) => ForgeConversationRun.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
    _validateForgeConversationRunPage(
      page,
      requestedConversationID: requestedConversationID,
      before: before,
      limit: limit,
    );
    return page;
  }
}

class ForgeRunTimelineEvent {
  final int sequence;
  final int emittedAtMS;
  final String type;

  const ForgeRunTimelineEvent({
    required this.sequence,
    required this.emittedAtMS,
    required this.type,
  });

  factory ForgeRunTimelineEvent.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {'seq', 'emitted_at_ms', 'type'});
    final sequence = _requiredNonNegativeInt(json, 'seq');
    final emittedAtMS = _requiredNonNegativeInt(json, 'emitted_at_ms');
    final type = _requiredExactText(json, 'type');
    if (sequence > _maxSafeForgeCursor ||
        emittedAtMS > _maxSafeForgeCursor ||
        !_forgeRunTimelineEventTypes.contains(type)) {
      throw const FormatException('Invalid Forge run timeline event.');
    }
    return ForgeRunTimelineEvent(
      sequence: sequence,
      emittedAtMS: emittedAtMS,
      type: type,
    );
  }
}

class ForgeRunTimelinePage {
  final String conversationID;
  final String runID;
  final int afterSequence;
  final int scannedThroughSequence;
  final bool hasMore;
  final List<ForgeRunTimelineEvent> events;

  const ForgeRunTimelinePage({
    required this.conversationID,
    required this.runID,
    required this.afterSequence,
    required this.scannedThroughSequence,
    required this.hasMore,
    required this.events,
  });

  factory ForgeRunTimelinePage.fromJson(
    ForgeJson json, {
    required String requestedConversationID,
    required String requestedRunID,
    required int requestedAfterSequence,
    int limit = _maxForgeRunTimelinePageSize,
  }) {
    if (limit < 1 || limit > _maxForgeRunTimelinePageSize) {
      throw const FormatException('Invalid Forge run timeline limit.');
    }
    _requireExactKeys(json, const {
      'conversation_id',
      'run_id',
      'after_sequence',
      'scanned_through_sequence',
      'has_more',
      'events',
    });
    final conversationID = _requiredExactText(json, 'conversation_id');
    final runID = _requiredExactText(json, 'run_id');
    final afterSequence = _requiredNonNegativeInt(json, 'after_sequence');
    final scannedThroughSequence = _requiredNonNegativeInt(
      json,
      'scanned_through_sequence',
    );
    final hasMore = json['has_more'];
    final rawEvents = json['events'];
    if (hasMore is! bool ||
        rawEvents is! List ||
        rawEvents.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge run timeline page.');
    }
    final page = ForgeRunTimelinePage(
      conversationID: conversationID,
      runID: runID,
      afterSequence: afterSequence,
      scannedThroughSequence: scannedThroughSequence,
      hasMore: hasMore,
      events: List.unmodifiable(
        rawEvents.map(
          (value) => ForgeRunTimelineEvent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
    );
    _validateForgeRunTimelinePage(
      page,
      requestedConversationID: requestedConversationID,
      requestedRunID: requestedRunID,
      requestedAfterSequence: requestedAfterSequence,
      limit: limit,
    );
    return page;
  }
}

void _validateForgeConversationRunPage(
  ForgeConversationRunPage page, {
  required String requestedConversationID,
  required ForgeRunCursor? before,
  required int limit,
}) {
  if (!_validFeedID(requestedConversationID) ||
      page.conversationID != requestedConversationID ||
      page.runs.length > limit ||
      page.hasMore != (page.nextCursor != null) ||
      (page.hasMore && page.runs.isEmpty)) {
    throw const FormatException('Invalid Forge run page.');
  }
  final runIDs = <String>{};
  for (var index = 0; index < page.runs.length; index++) {
    final run = page.runs[index];
    if (!runIDs.add(run.runID) ||
        (index > 0 &&
            _compareForgeRunsNewestFirst(page.runs[index - 1], run) >= 0) ||
        (before != null && _runIsNotBeforeCursor(run, before))) {
      throw const FormatException('Invalid Forge run page order.');
    }
  }
  if (page.hasMore) {
    final last = page.runs.last;
    final cursor = page.nextCursor!;
    if (cursor.createdAtMS != last.createdAtMS ||
        cursor.runID != last.runID ||
        (before != null &&
            !_runKeyIsOlder(cursor.createdAtMS, cursor.runID, before))) {
      throw const FormatException('Invalid Forge run cursor.');
    }
  }
}

void _validateForgeRunTimelinePage(
  ForgeRunTimelinePage page, {
  required String requestedConversationID,
  required String requestedRunID,
  required int requestedAfterSequence,
  required int limit,
}) {
  if (!_validFeedID(requestedConversationID) ||
      !_validFeedID(requestedRunID) ||
      requestedAfterSequence < 0 ||
      requestedAfterSequence > _maxSafeForgeCursor ||
      page.conversationID != requestedConversationID ||
      page.runID != requestedRunID ||
      page.afterSequence != requestedAfterSequence ||
      page.scannedThroughSequence > _maxSafeForgeCursor ||
      page.scannedThroughSequence < requestedAfterSequence ||
      page.events.length > limit ||
      (page.hasMore && page.events.isEmpty)) {
    throw const FormatException('Invalid Forge run timeline page.');
  }
  var expectedSequence = requestedAfterSequence;
  for (final event in page.events) {
    if (expectedSequence >= _maxSafeForgeCursor ||
        event.sequence != expectedSequence + 1) {
      throw const FormatException('Invalid Forge run timeline order.');
    }
    expectedSequence = event.sequence;
  }
  if (page.events.isEmpty) {
    if (page.hasMore || page.scannedThroughSequence != requestedAfterSequence) {
      throw const FormatException('Invalid empty Forge run timeline page.');
    }
  } else if (page.scannedThroughSequence != expectedSequence) {
    throw const FormatException('Invalid Forge run timeline cursor.');
  }
}

bool _runIsNotBeforeCursor(ForgeConversationRun run, ForgeRunCursor before) =>
    !_runKeyIsOlder(run.createdAtMS, run.runID, before);

bool _runKeyIsOlder(int createdAtMS, String runID, ForgeRunCursor before) =>
    createdAtMS < before.createdAtMS ||
    (createdAtMS == before.createdAtMS &&
        _compareForgeID(runID, before.runID) < 0);

int _compareForgeRunsNewestFirst(
  ForgeConversationRun left,
  ForgeConversationRun right,
) {
  final byTime = right.createdAtMS.compareTo(left.createdAtMS);
  return byTime != 0 ? byTime : _compareForgeID(right.runID, left.runID);
}

int _compareForgeID(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  final sharedLength = leftBytes.length < rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < sharedLength; index++) {
    final byByte = leftBytes[index].compareTo(rightBytes[index]);
    if (byByte != 0) return byByte;
  }
  return leftBytes.length.compareTo(rightBytes.length);
}
