import 'dart:convert';

typedef ForgeJson = Map<String, dynamic>;

const _maxSafeForgeCursor = 9007199254740991;
const _maxForgePromptIDBytes = 128;
const _maxForgePromptRoleBytes = 64;
const _maxForgePromptContentBytes = 256 * 1024;
const _maxForgeConversationPageSize = 128;
const _maxForgePromptPageSize = 128;
const _maxForgeRunPageSize = 25;
const _maxForgeRunTimelinePageSize = 128;

const _forgeRunStatuses = {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
};

const _forgeRunTimelineEventTypes = {
  'run_started',
  'turn_started',
  'activity',
  'run_finished',
};

class ForgeConversationScope {
  final String kind;
  final String? id;

  const ForgeConversationScope({required this.kind, this.id});

  factory ForgeConversationScope.fromJson(ForgeJson json) {
    const required = {'kind'};
    const allowed = {...required, 'id'};
    if (!required.every(json.containsKey) ||
        json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Forge returned unexpected response fields.');
    }
    final kind = _requiredExactText(json, 'kind');
    final rawID = json['id'];
    if (json.containsKey('id') && rawID is! String) {
      throw const FormatException('Invalid Forge conversation scope.');
    }
    final id = rawID as String? ?? '';
    final hasID = json.containsKey('id');
    if (kind == 'global' && hasID) {
      throw const FormatException('Invalid Forge conversation scope.');
    }
    if ((kind == 'project' || kind == 'group') &&
        (!hasID || !_validConversationID(id))) {
      throw const FormatException('Invalid Forge conversation scope.');
    }
    if (!const {'global', 'project', 'group'}.contains(kind)) {
      throw const FormatException('Invalid Forge conversation scope.');
    }
    return ForgeConversationScope(kind: kind, id: id.isEmpty ? null : id);
  }

  ForgeJson toJson() => {'kind': kind, if (id != null) 'id': id};

  String get label => id == null ? kind : '$kind · $id';
}

class ForgeConversation {
  final String id;
  final ForgeConversationScope scope;
  final String title;
  final int createdAtMS;
  final int updatedAtMS;

  const ForgeConversation({
    required this.id,
    required this.scope,
    required this.title,
    required this.createdAtMS,
    required this.updatedAtMS,
  });

  factory ForgeConversation.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'id',
      'scope',
      'title',
      'created_at_ms',
      'updated_at_ms',
    });
    final conversation = ForgeConversation(
      id: _requiredExactText(json, 'id'),
      scope: ForgeConversationScope.fromJson(_requiredObject(json, 'scope')),
      title: _requiredExactText(json, 'title'),
      createdAtMS: _requiredNonNegativeInt(json, 'created_at_ms'),
      updatedAtMS: _requiredNonNegativeInt(json, 'updated_at_ms'),
    );
    if (!_validConversationID(conversation.id) ||
        conversation.title.trim().isEmpty) {
      throw const FormatException('Invalid Forge conversation.');
    }
    return conversation;
  }
}

class ForgeOwnedConversation {
  final ForgeConversation conversation;
  final int aggregateVersion;

  const ForgeOwnedConversation({
    required this.conversation,
    required this.aggregateVersion,
  });

  factory ForgeOwnedConversation.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {'conversation', 'aggregate_version'});
    return ForgeOwnedConversation(
      conversation: ForgeConversation.fromJson(
        _requiredObject(json, 'conversation'),
      ),
      aggregateVersion: _requiredPositiveInt(json, 'aggregate_version'),
    );
  }
}

class ForgeConversationPage {
  final List<ForgeOwnedConversation> conversations;
  final String? nextAfterID;
  final bool hasMore;

  const ForgeConversationPage({
    required this.conversations,
    required this.nextAfterID,
    required this.hasMore,
  });

  factory ForgeConversationPage.fromJson(
    ForgeJson json, {
    int limit = _maxForgePromptPageSize,
    String? afterID,
  }) {
    const required = {'conversations', 'has_more'};
    const allowed = {...required, 'next_after_id'};
    if (!required.every(json.containsKey) ||
        json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Forge returned unexpected response fields.');
    }
    if (limit < 1 || limit > _maxForgeConversationPageSize) {
      throw const FormatException('Invalid Forge conversation page limit.');
    }
    if (afterID != null && !_validConversationID(afterID)) {
      throw const FormatException('Invalid Forge conversation cursor.');
    }
    final raw = json['conversations'];
    if (raw is! List || raw.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge conversation page.');
    }
    final conversations = raw
        .map(
          (value) => ForgeOwnedConversation.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final rawCursor = json['next_after_id'];
    if (rawCursor != null && (rawCursor is! String || rawCursor.isEmpty)) {
      throw const FormatException('Invalid Forge conversation cursor.');
    }
    final hasMore = json['has_more'];
    if (hasMore is! bool) {
      throw const FormatException('Invalid Forge conversation page.');
    }
    final page = ForgeConversationPage(
      conversations: List.unmodifiable(conversations),
      nextAfterID: rawCursor as String?,
      hasMore: hasMore,
    );
    _validateForgeConversationPage(page, limit, afterID);
    return page;
  }
}

class ForgePromptCursor {
  final int createdAtMS;
  final String promptID;

  const ForgePromptCursor({required this.createdAtMS, required this.promptID});

  factory ForgePromptCursor.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {'created_at_ms', 'prompt_id'});
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    if (createdAtMS > _maxSafeForgeCursor) {
      throw const FormatException('Invalid Forge prompt cursor.');
    }
    return ForgePromptCursor(
      createdAtMS: createdAtMS,
      promptID: _requiredExactText(json, 'prompt_id'),
    );
  }
}

class ForgeConversationPrompt {
  final String id;
  final String conversationID;
  final String role;
  final String content;
  final int createdAtMS;

  const ForgeConversationPrompt({
    required this.id,
    required this.conversationID,
    required this.role,
    required this.content,
    required this.createdAtMS,
  });

  factory ForgeConversationPrompt.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'id',
      'conversation_id',
      'role',
      'content',
      'created_at_ms',
    });
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    if (createdAtMS > _maxSafeForgeCursor) {
      throw const FormatException('Invalid Forge prompt.');
    }
    return ForgeConversationPrompt(
      id: _requiredExactText(json, 'id'),
      conversationID: _requiredExactText(json, 'conversation_id'),
      role: _requiredExactText(json, 'role'),
      content: _requiredExactText(json, 'content'),
      createdAtMS: createdAtMS,
    );
  }
}

class ForgeConversationPromptPage {
  final String conversationID;
  final List<ForgeConversationPrompt> prompts;
  final ForgePromptCursor? nextCursor;
  final bool hasMore;

  const ForgeConversationPromptPage({
    required this.conversationID,
    required this.prompts,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ForgeConversationPromptPage.fromJson(
    ForgeJson json, {
    int limit = _maxForgePromptPageSize,
  }) {
    const required = {'conversation_id', 'prompts', 'has_more'};
    const allowed = {...required, 'next_cursor'};
    if (!required.every(json.containsKey) ||
        json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Forge returned unexpected response fields.');
    }
    if (limit < 1 || limit > _maxForgePromptPageSize) {
      throw const FormatException('Invalid Forge prompt page limit.');
    }
    final raw = json['prompts'];
    if (raw is! List || raw.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    final rawCursor = json['next_cursor'];
    final cursor = rawCursor == null
        ? null
        : ForgePromptCursor.fromJson(_asObject(rawCursor));
    final hasMore = json['has_more'];
    if (hasMore is! bool) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    final page = ForgeConversationPromptPage(
      conversationID: _requiredExactText(json, 'conversation_id'),
      prompts: List.unmodifiable(
        raw.map(
          (value) => ForgeConversationPrompt.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      nextCursor: cursor,
      hasMore: hasMore,
    );
    _validateForgePromptPage(page, limit);
    return page;
  }
}

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

void _validateForgePromptPage(ForgeConversationPromptPage page, int limit) {
  if (page.conversationID.trim().isEmpty || page.prompts.length > limit) {
    throw const FormatException('Invalid Forge prompt page.');
  }
  var contentBytes = 0;
  ForgeConversationPrompt? previous;
  final promptIDs = <String>{};
  for (final prompt in page.prompts) {
    final idBytes = utf8.encode(prompt.id).length;
    final roleBytes = utf8.encode(prompt.role).length;
    final promptBytes = utf8.encode(prompt.content).length;
    if (prompt.conversationID != page.conversationID ||
        prompt.id.trim().isEmpty ||
        idBytes > _maxForgePromptIDBytes ||
        prompt.id.runes.any(_isForgeControlRune) ||
        prompt.role.isEmpty ||
        roleBytes > _maxForgePromptRoleBytes ||
        promptBytes > _maxForgePromptContentBytes ||
        !promptIDs.add(prompt.id)) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    contentBytes += promptBytes;
    if (contentBytes > _maxForgePromptContentBytes ||
        (previous != null &&
            (previous.createdAtMS < prompt.createdAtMS ||
                (previous.createdAtMS == prompt.createdAtMS &&
                    _compareForgePromptIDs(previous.id, prompt.id) <= 0)))) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    previous = prompt;
  }

  final cursor = page.nextCursor;
  if (page.hasMore) {
    if (page.prompts.isEmpty ||
        cursor == null ||
        cursor.createdAtMS != page.prompts.last.createdAtMS ||
        cursor.promptID != page.prompts.last.id) {
      throw const FormatException('Invalid Forge prompt page cursor.');
    }
  } else if (cursor != null) {
    throw const FormatException('Invalid Forge prompt page cursor.');
  }
}

bool _isForgeControlRune(int rune) =>
    rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);

int _compareForgePromptIDs(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  final sharedLength = leftBytes.length < rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < sharedLength; index++) {
    final difference = leftBytes[index] - rightBytes[index];
    if (difference != 0) return difference;
  }
  return leftBytes.length.compareTo(rightBytes.length);
}

class ForgePromptAppendResult {
  final ForgeConversationPrompt prompt;
  final int aggregateVersion;
  final bool replayed;

  const ForgePromptAppendResult({
    required this.prompt,
    required this.aggregateVersion,
    required this.replayed,
  });

  factory ForgePromptAppendResult.fromJson(ForgeJson json) {
    final replayed = json['replayed'];
    if (replayed is! bool) {
      throw const FormatException('Invalid Forge prompt response.');
    }
    return ForgePromptAppendResult(
      prompt: ForgeConversationPrompt.fromJson(_requiredObject(json, 'prompt')),
      aggregateVersion: _requiredPositiveInt(json, 'aggregate_version'),
      replayed: replayed,
    );
  }
}

class ForgeConversationChange {
  final int cursor;
  final int schemaVersion;
  final String conversationID;
  final String entityID;
  final int aggregateVersion;
  final String kind;
  final int createdAtMS;

  const ForgeConversationChange({
    required this.cursor,
    required this.schemaVersion,
    required this.conversationID,
    required this.entityID,
    required this.aggregateVersion,
    required this.kind,
    required this.createdAtMS,
  });

  factory ForgeConversationChange.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'cursor',
      'schema_version',
      'conversation_id',
      'entity_id',
      'aggregate_version',
      'kind',
      'created_at_ms',
    });
    final kind = _requiredText(json, 'kind');
    if (!const {'conversation_created', 'prompt_appended'}.contains(kind)) {
      throw const FormatException('Invalid Forge conversation change kind.');
    }
    final cursor = _requiredPositiveInt(json, 'cursor');
    final schemaVersion = _requiredPositiveInt(json, 'schema_version');
    if (schemaVersion != 1) {
      throw const FormatException('Invalid Forge conversation change schema.');
    }
    final conversationID = _requiredText(json, 'conversation_id');
    final entityID = _requiredText(json, 'entity_id');
    if (!_validFeedID(conversationID) ||
        !_validFeedID(entityID) ||
        (kind == 'conversation_created' && entityID != conversationID)) {
      throw const FormatException('Invalid Forge conversation change IDs.');
    }
    return ForgeConversationChange(
      cursor: cursor,
      schemaVersion: schemaVersion,
      conversationID: conversationID,
      entityID: entityID,
      aggregateVersion: _requiredPositiveInt(json, 'aggregate_version'),
      kind: kind,
      createdAtMS: _requiredNonNegativeInt(json, 'created_at_ms'),
    );
  }
}

/// Dense owner-local replay page. Its cursor does not expose global journal
/// activity from other principals.
class ForgeConversationChangePage {
  final int afterCursor;
  final int scannedThroughCursor;
  final bool hasMore;
  final List<ForgeConversationChange> changes;

  const ForgeConversationChangePage({
    required this.afterCursor,
    required this.scannedThroughCursor,
    required this.hasMore,
    required this.changes,
  });

  factory ForgeConversationChangePage.fromJson(
    ForgeJson json, {
    required int requestedAfterCursor,
    required int limit,
  }) {
    _requireExactKeys(json, const {
      'after_cursor',
      'scanned_through_cursor',
      'has_more',
      'changes',
    });
    final afterCursor = _requiredNonNegativeInt(json, 'after_cursor');
    final scannedThroughCursor = _requiredNonNegativeInt(
      json,
      'scanned_through_cursor',
    );
    final hasMore = json['has_more'];
    final raw = json['changes'];
    if (requestedAfterCursor > _maxSafeForgeCursor ||
        afterCursor != requestedAfterCursor ||
        scannedThroughCursor > _maxSafeForgeCursor ||
        scannedThroughCursor < afterCursor ||
        hasMore is! bool ||
        raw is! List ||
        raw.length > limit ||
        raw.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge conversation change page.');
    }
    final changes = raw
        .map(
          (value) => ForgeConversationChange.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    if (changes.isEmpty) {
      if (hasMore || scannedThroughCursor != afterCursor) {
        throw const FormatException('Forge change page made invalid progress.');
      }
    } else if ((hasMore && changes.length != limit) ||
        changes.last.cursor != scannedThroughCursor) {
      throw const FormatException('Forge change page made invalid progress.');
    }
    var previous = afterCursor;
    for (final change in changes) {
      if (previous >= _maxSafeForgeCursor ||
          change.cursor != previous + 1 ||
          change.cursor > scannedThroughCursor ||
          change.cursor > _maxSafeForgeCursor ||
          change.conversationID.length > 128 ||
          change.entityID.length > 128) {
        throw const FormatException('Invalid Forge conversation change order.');
      }
      previous = change.cursor;
    }
    if (hasMore && scannedThroughCursor == afterCursor) {
      throw const FormatException('Forge change page made no cursor progress.');
    }
    return ForgeConversationChangePage(
      afterCursor: afterCursor,
      scannedThroughCursor: scannedThroughCursor,
      hasMore: hasMore,
      changes: List.unmodifiable(changes),
    );
  }
}

bool _validFeedID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validConversationID(String value) =>
    _validFeedID(value) && !value.contains('/');

void _validateForgeConversationPage(
  ForgeConversationPage page,
  int limit,
  String? afterID,
) {
  if (page.conversations.length > limit ||
      (page.hasMore && page.conversations.length != limit) ||
      (page.hasMore && page.nextAfterID == null) ||
      (!page.hasMore && page.nextAfterID != null)) {
    throw const FormatException('Invalid Forge conversation page.');
  }
  var previousID = afterID;
  for (final entry in page.conversations) {
    final id = entry.conversation.id;
    if (!_validConversationID(id) ||
        (previousID != null && _compareCodePoints(previousID, id) >= 0)) {
      throw const FormatException('Invalid Forge conversation order.');
    }
    previousID = id;
  }
  if (page.hasMore &&
      page.nextAfterID != page.conversations.last.conversation.id) {
    throw const FormatException('Invalid Forge conversation cursor.');
  }
}

int _compareCodePoints(String left, String right) {
  final leftRunes = left.runes.toList(growable: false);
  final rightRunes = right.runes.toList(growable: false);
  final sharedLength = leftRunes.length < rightRunes.length
      ? leftRunes.length
      : rightRunes.length;
  for (var index = 0; index < sharedLength; index++) {
    final comparison = leftRunes[index].compareTo(rightRunes[index]);
    if (comparison != 0) return comparison;
  }
  return leftRunes.length.compareTo(rightRunes.length);
}

ForgeJson _asObject(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge API response.');
  }
  return Map<String, dynamic>.from(value);
}

void _requireExactKeys(ForgeJson json, Set<String> expected) {
  if (json.length != expected.length || !json.keys.every(expected.contains)) {
    throw const FormatException('Forge returned unexpected response fields.');
  }
}

ForgeJson _requiredObject(ForgeJson json, String key) => _asObject(json[key]);

String _requiredText(ForgeJson json, String key) {
  final value = _optionalText(json, key);
  if (value.isEmpty) {
    throw FormatException('Missing Forge response field: $key.');
  }
  return value;
}

String _requiredExactText(ForgeJson json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid Forge response field: $key.');
  }
  return value;
}

String _optionalText(ForgeJson json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is! String) {
    throw FormatException('Invalid Forge response field: $key.');
  }
  return value.trim();
}

int _requiredNonNegativeInt(ForgeJson json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Invalid Forge response field: $key.');
  }
  return value;
}

int _requiredPositiveInt(ForgeJson json, String key) {
  final value = json[key];
  if (value is! int || value < 1) {
    throw FormatException('Invalid Forge response field: $key.');
  }
  return value;
}
