part of 'forge_pending_run_intent.dart';

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
