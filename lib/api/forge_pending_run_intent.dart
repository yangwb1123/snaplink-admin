import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

part 'forge_pending_run_intent_fixture.dart';
part 'forge_pending_run_intent_codec.dart';

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
    if (record.aggregateVersion == 0 ||
        record.status != 'pending' ||
        record.latestSequence != 1) {
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
