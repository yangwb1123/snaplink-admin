import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

/// Strict consumer for the pending Run-intent receipt contract.
///
/// A pending intent is a consent receipt. It does not mean a Run exists and
/// this model never treats it as authority to select, reserve, dispatch, or
/// execute anything.
const forgePendingRunIntentSchema = 'forge.pending-run-intent/v1';
const forgePendingRunIntentEvaluationMode =
    'owner_scoped_pending_intent_preview';
const forgePendingRunIntentMaxSafeInteger = 9007199254740991;

class ForgePendingRunIntentAuthority {
  final bool deviceIdentityVerified;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool runCreated;
  final bool auditPublished;

  const ForgePendingRunIntentAuthority({
    required this.deviceIdentityVerified,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.runCreated,
    required this.auditPublished,
  });

  bool get isOffline =>
      !deviceIdentityVerified &&
      !inventoryAuthoritative &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !runCreated &&
      !auditPublished;

  factory ForgePendingRunIntentAuthority.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'authority');
    _pendingIntentExactKeys(json, {
      'device_identity_verified',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'run_created',
      'audit_published',
    });
    final authority = ForgePendingRunIntentAuthority(
      deviceIdentityVerified: _pendingIntentBool(
        json['device_identity_verified'],
      ),
      inventoryAuthoritative: _pendingIntentBool(
        json['inventory_authoritative'],
      ),
      reservationCreated: _pendingIntentBool(json['reservation_created']),
      executionAuthorized: _pendingIntentBool(json['execution_authorized']),
      dispatchPerformed: _pendingIntentBool(json['dispatch_performed']),
      runCreated: _pendingIntentBool(json['run_created']),
      auditPublished: _pendingIntentBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge pending Run-intent authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgePendingRunIntentPrompt {
  final String id;
  final String conversationID;
  final String role;
  final String content;
  final int createdAtMS;

  const ForgePendingRunIntentPrompt({
    required this.id,
    required this.conversationID,
    required this.role,
    required this.content,
    required this.createdAtMS,
  });

  factory ForgePendingRunIntentPrompt.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'prompt');
    _pendingIntentExactKeys(json, {
      'id',
      'conversation_id',
      'role',
      'content',
      'created_at_ms',
    });
    return ForgePendingRunIntentPrompt(
      id: _pendingIntentText(json['id'], 'prompt.id'),
      conversationID: _pendingIntentText(
        json['conversation_id'],
        'prompt.conversation_id',
      ),
      role: _pendingIntentText(json['role'], 'prompt.role'),
      content: _pendingIntentContent(json['content']),
      createdAtMS: _pendingIntentSafeUInt(
        json['created_at_ms'],
        'created_at_ms',
      ),
    );
  }
}

class ForgePendingRunIntentRecord {
  final String intentID;
  final String conversationID;
  final String promptID;
  final String projectID;
  final String profileID;
  final int submittedAtMS;
  final int aggregateVersion;
  final int latestSequence;
  final String status;

  const ForgePendingRunIntentRecord({
    required this.intentID,
    required this.conversationID,
    required this.promptID,
    required this.projectID,
    required this.profileID,
    required this.submittedAtMS,
    required this.aggregateVersion,
    required this.latestSequence,
    required this.status,
  });

  factory ForgePendingRunIntentRecord.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'intent');
    _pendingIntentExactKeys(json, {
      'intent_id',
      'conversation_id',
      'prompt_id',
      'project_id',
      'profile_id',
      'submitted_at_ms',
      'aggregate_version',
      'latest_sequence',
      'status',
    });
    final record = ForgePendingRunIntentRecord(
      intentID: _pendingIntentText(json['intent_id'], 'intent_id'),
      conversationID: _pendingIntentText(
        json['conversation_id'],
        'intent.conversation_id',
      ),
      promptID: _pendingIntentText(json['prompt_id'], 'intent.prompt_id'),
      projectID: _pendingIntentText(json['project_id'], 'intent.project_id'),
      profileID: _pendingIntentText(json['profile_id'], 'intent.profile_id'),
      submittedAtMS: _pendingIntentSafeUInt(
        json['submitted_at_ms'],
        'submitted_at_ms',
      ),
      aggregateVersion: _pendingIntentSafeUInt(
        json['aggregate_version'],
        'aggregate_version',
      ),
      latestSequence: _pendingIntentSafeUInt(
        json['latest_sequence'],
        'latest_sequence',
      ),
      status: _pendingIntentText(json['status'], 'intent.status'),
    );
    if (record.status != 'pending' || record.latestSequence != 1) {
      throw const FormatException(
        'Forge pending Run-intent record is not the initial pending value.',
      );
    }
    return record;
  }

  bool sameValue(ForgePendingRunIntentRecord other) =>
      intentID == other.intentID &&
      conversationID == other.conversationID &&
      promptID == other.promptID &&
      projectID == other.projectID &&
      profileID == other.profileID &&
      submittedAtMS == other.submittedAtMS &&
      aggregateVersion == other.aggregateVersion &&
      latestSequence == other.latestSequence &&
      status == other.status;
}

class ForgePendingRunIntentEvent {
  final String eventID;
  final int sequence;
  final int emittedAtMS;
  final String type;

  const ForgePendingRunIntentEvent({
    required this.eventID,
    required this.sequence,
    required this.emittedAtMS,
    required this.type,
  });

  factory ForgePendingRunIntentEvent.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'event');
    _pendingIntentExactKeys(json, {'event_id', 'seq', 'emitted_at_ms', 'type'});
    final event = ForgePendingRunIntentEvent(
      eventID: _pendingIntentText(json['event_id'], 'event_id'),
      sequence: _pendingIntentSafeUInt(json['seq'], 'event.seq'),
      emittedAtMS: _pendingIntentSafeUInt(
        json['emitted_at_ms'],
        'event.emitted_at_ms',
      ),
      type: _pendingIntentText(json['type'], 'event.type'),
    );
    if (event.sequence != 1 || event.type != 'submitted') {
      throw const FormatException(
        'Forge pending Run-intent event is not the initial submitted value.',
      );
    }
    return event;
  }

  bool sameValue(ForgePendingRunIntentEvent other) =>
      eventID == other.eventID &&
      sequence == other.sequence &&
      emittedAtMS == other.emittedAtMS &&
      type == other.type;
}

class ForgePendingRunIntentSubmission {
  final ForgePendingRunIntentPrompt prompt;
  final ForgePendingRunIntentRecord intent;
  final ForgePendingRunIntentEvent initialEvent;
  final bool replayed;

  const ForgePendingRunIntentSubmission({
    required this.prompt,
    required this.intent,
    required this.initialEvent,
    required this.replayed,
  });

  factory ForgePendingRunIntentSubmission.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'submission');
    _pendingIntentExactKeys(json, {
      'prompt',
      'intent',
      'initial_event',
      'replayed',
    });
    return ForgePendingRunIntentSubmission(
      prompt: ForgePendingRunIntentPrompt.fromJson(json['prompt']),
      intent: ForgePendingRunIntentRecord.fromJson(json['intent']),
      initialEvent: ForgePendingRunIntentEvent.fromJson(json['initial_event']),
      replayed: _pendingIntentBool(json['replayed']),
    );
  }
}

class ForgePendingRunIntentPage {
  final String conversationID;
  final ForgePendingRunIntentRecord intent;
  final bool hasMore;

  const ForgePendingRunIntentPage({
    required this.conversationID,
    required this.intent,
    required this.hasMore,
  });

  factory ForgePendingRunIntentPage.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'page');
    _pendingIntentExactKeys(json, {
      'conversation_id',
      'intents',
      'next_cursor',
      'has_more',
    });
    final intents = json['intents'];
    if (intents is! List ||
        intents.length != 1 ||
        json['next_cursor'] != null) {
      throw const FormatException(
        'Forge pending Run-intent page must contain one bounded initial record.',
      );
    }
    return ForgePendingRunIntentPage(
      conversationID: _pendingIntentText(
        json['conversation_id'],
        'page.conversation_id',
      ),
      intent: ForgePendingRunIntentRecord.fromJson(intents.single),
      hasMore: _pendingIntentBool(json['has_more']),
    );
  }
}

class ForgePendingRunIntentTimeline {
  final String conversationID;
  final String intentID;
  final int afterSequence;
  final int scannedThroughSequence;
  final bool hasMore;
  final ForgePendingRunIntentEvent event;

  const ForgePendingRunIntentTimeline({
    required this.conversationID,
    required this.intentID,
    required this.afterSequence,
    required this.scannedThroughSequence,
    required this.hasMore,
    required this.event,
  });

  factory ForgePendingRunIntentTimeline.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'timeline');
    _pendingIntentExactKeys(json, {
      'conversation_id',
      'intent_id',
      'after_sequence',
      'scanned_through_sequence',
      'has_more',
      'events',
    });
    final events = json['events'];
    if (events is! List || events.length != 1) {
      throw const FormatException(
        'Forge pending Run-intent timeline must contain one event.',
      );
    }
    final timeline = ForgePendingRunIntentTimeline(
      conversationID: _pendingIntentText(
        json['conversation_id'],
        'timeline.conversation_id',
      ),
      intentID: _pendingIntentText(json['intent_id'], 'timeline.intent_id'),
      afterSequence: _pendingIntentSafeUInt(
        json['after_sequence'],
        'timeline.after_sequence',
      ),
      scannedThroughSequence: _pendingIntentSafeUInt(
        json['scanned_through_sequence'],
        'timeline.scanned_through_sequence',
      ),
      hasMore: _pendingIntentBool(json['has_more']),
      event: ForgePendingRunIntentEvent.fromJson(events.single),
    );
    if (timeline.afterSequence != 0 ||
        timeline.scannedThroughSequence != 1 ||
        timeline.hasMore) {
      throw const FormatException(
        'Forge pending Run-intent timeline is not the initial bounded page.',
      );
    }
    return timeline;
  }
}

class ForgePendingRunIntentFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgePendingRunIntentAuthority authority;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final ForgePendingRunIntentSubmission submission;
  final ForgePendingRunIntentPage page;
  final ForgePendingRunIntentTimeline timeline;
  final String promptRole;
  final String intentStatus;
  final String initialEventType;
  final int timelineEventCount;
  final bool replayed;

  const ForgePendingRunIntentFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.owner,
    required this.conversationID,
    required this.submission,
    required this.page,
    required this.timeline,
    required this.promptRole,
    required this.intentStatus,
    required this.initialEventType,
    required this.timelineEventCount,
    required this.replayed,
  });

  bool get isDisplayOnly =>
      authority.isOffline &&
      submission.prompt.role == promptRole &&
      submission.intent.status == intentStatus &&
      submission.initialEvent.type == initialEventType &&
      submission.replayed == replayed &&
      timelineEventCount == 1;

  factory ForgePendingRunIntentFixture.fromJson(Object? value) {
    final json = _pendingIntentObject(value, 'fixture');
    _pendingIntentExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'owner',
      'conversation_id',
      'submission',
      'page',
      'timeline',
      'expected',
    });
    if (json['schema_version'] != forgePendingRunIntentSchema ||
        json['evaluation_mode'] != forgePendingRunIntentEvaluationMode) {
      throw const FormatException(
        'Invalid Forge pending Run-intent contract envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final conversationID = _pendingIntentText(
      json['conversation_id'],
      'conversation_id',
    );
    final submission = ForgePendingRunIntentSubmission.fromJson(
      json['submission'],
    );
    final page = ForgePendingRunIntentPage.fromJson(json['page']);
    final timeline = ForgePendingRunIntentTimeline.fromJson(json['timeline']);
    final expected = _pendingIntentObject(json['expected'], 'expected');
    _pendingIntentExactKeys(expected, {
      'prompt_role',
      'intent_status',
      'initial_event_type',
      'timeline_event_count',
      'replayed',
    });
    final promptRole = _pendingIntentText(
      expected['prompt_role'],
      'expected.prompt_role',
    );
    final intentStatus = _pendingIntentText(
      expected['intent_status'],
      'expected.intent_status',
    );
    final initialEventType = _pendingIntentText(
      expected['initial_event_type'],
      'expected.initial_event_type',
    );
    final eventCount = _pendingIntentSafeUInt(
      expected['timeline_event_count'],
      'expected.timeline_event_count',
    );
    final replayed = _pendingIntentBool(expected['replayed']);
    if (submission.prompt.conversationID != conversationID ||
        submission.prompt.role != 'user' ||
        submission.prompt.id != submission.intent.promptID ||
        submission.prompt.createdAtMS != submission.intent.submittedAtMS ||
        submission.intent.conversationID != conversationID ||
        submission.initialEvent.sequence != 1 ||
        submission.initialEvent.emittedAtMS !=
            submission.intent.submittedAtMS ||
        page.conversationID != conversationID ||
        !page.intent.sameValue(submission.intent) ||
        page.hasMore ||
        timeline.conversationID != conversationID ||
        timeline.intentID != submission.intent.intentID ||
        !timeline.event.sameValue(submission.initialEvent) ||
        promptRole != submission.prompt.role ||
        intentStatus != submission.intent.status ||
        initialEventType != submission.initialEvent.type ||
        eventCount != 1 ||
        replayed != submission.replayed) {
      throw const FormatException(
        'Forge pending Run-intent fixture binding or expectation drift.',
      );
    }
    final fixture = ForgePendingRunIntentFixture(
      schemaVersion: forgePendingRunIntentSchema,
      evaluationMode: forgePendingRunIntentEvaluationMode,
      authority: ForgePendingRunIntentAuthority.fromJson(json['authority']),
      owner: owner,
      conversationID: conversationID,
      submission: submission,
      page: page,
      timeline: timeline,
      promptRole: promptRole,
      intentStatus: intentStatus,
      initialEventType: initialEventType,
      timelineEventCount: eventCount,
      replayed: replayed,
    );
    if (!fixture.isDisplayOnly) {
      throw const FormatException(
        'Forge pending Run-intent fixture claims authority.',
      );
    }
    return fixture;
  }

  factory ForgePendingRunIntentFixture.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge pending Run-intent fixture is too large.',
      );
    }
    _pendingIntentRejectDuplicateKeys(source);
    try {
      return ForgePendingRunIntentFixture.fromJson(jsonDecode(source));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid Forge pending Run-intent JSON.');
    }
  }
}

Map<String, dynamic> _pendingIntentObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Forge pending Run-intent $label must be an object.');
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _pendingIntentExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Forge pending Run-intent fixture has unknown or missing fields.',
    );
  }
}

bool _pendingIntentBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Forge pending Run-intent flag must be boolean.',
    );
  }
  return value;
}

String _pendingIntentText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.length > 512) {
    throw FormatException('Invalid Forge pending Run-intent $label.');
  }
  return value;
}

String _pendingIntentContent(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 256 * 1024) {
    throw const FormatException('Invalid Forge pending Run-intent prompt.');
  }
  return value;
}

int _pendingIntentSafeUInt(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgePendingRunIntentMaxSafeInteger) {
    throw FormatException('Invalid Forge pending Run-intent $label.');
  }
  return value;
}

void _pendingIntentRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge pending Run-intent JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge pending Run-intent JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge pending Run-intent JSON.');
  }
}
