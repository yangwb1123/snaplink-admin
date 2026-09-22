part of 'forge_sessions_screen.dart';

const _forgeAuthRequiredMessage =
    'Forge access is missing. Sign in with Forge conversation permissions.';

List<ForgeOwnedConversation> _mergeConversations({
  required List<ForgeOwnedConversation> incoming,
  required List<ForgeOwnedConversation> existing,
  required bool append,
}) {
  final values = <String, ForgeOwnedConversation>{};
  final existingByID = <String, ForgeOwnedConversation>{
    for (final item in existing) item.conversation.id: item,
  };
  if (append) {
    for (final item in existing) {
      values[item.conversation.id] = item;
    }
  }
  for (final item in incoming) {
    final prior =
        values[item.conversation.id] ?? existingByID[item.conversation.id];
    if (prior == null || item.aggregateVersion >= prior.aggregateVersion) {
      values[item.conversation.id] = item;
    } else if (!append) {
      // A feed response may have applied a newer aggregate version while this
      // snapshot was in flight. Keep that newer value without retaining other
      // rows that the authoritative first page omitted.
      values[item.conversation.id] = prior;
    }
  }
  return List.unmodifiable(values.values);
}

ForgeOwnedConversation? _findConversation(
  List<ForgeOwnedConversation> items,
  String? id,
) {
  if (id == null) return null;
  for (final item in items) {
    if (item.conversation.id == id) return item;
  }
  return null;
}

List<ForgeOwnedConversation> _replaceConversation(
  List<ForgeOwnedConversation> items,
  ForgeOwnedConversation updated,
) => List.unmodifiable([
  for (final item in items)
    if (item.conversation.id == updated.conversation.id) updated else item,
]);

int _comparePrompts(
  ForgeConversationPrompt left,
  ForgeConversationPrompt right,
) {
  final byTime = left.createdAtMS.compareTo(right.createdAtMS);
  return byTime != 0 ? byTime : left.id.compareTo(right.id);
}

List<ForgeConversationPrompt> _uniquePrompts(
  List<ForgeConversationPrompt> items,
) {
  final unique = <String, ForgeConversationPrompt>{};
  for (final prompt in items) {
    unique[prompt.id] = prompt;
  }
  return List.unmodifiable(unique.values);
}

List<ForgeConversationRun> _uniqueRuns(List<ForgeConversationRun> items) {
  final unique = <String, ForgeConversationRun>{};
  for (final run in items) {
    unique[run.runID] = run;
  }
  return List.unmodifiable(unique.values);
}

ForgeConversationRun? _findRun(
  List<ForgeConversationRun> items,
  String? runID,
) {
  if (runID == null) return null;
  for (final run in items) {
    if (run.runID == runID) return run;
  }
  return null;
}

List<ForgeRunTimelineEvent> _uniqueRunEvents(
  List<ForgeRunTimelineEvent> items,
) {
  final unique = <int, ForgeRunTimelineEvent>{};
  for (final event in items) {
    unique[event.sequence] = event;
  }
  return List.unmodifiable(unique.values);
}

String newForgeIdempotencyKey({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class _PendingCreate {
  final String title;
  final ForgeConversationScope scope;
  final String idempotencyKey;

  const _PendingCreate({
    required this.title,
    required this.scope,
    required this.idempotencyKey,
  });
}

class _PendingPrompt {
  final String content;
  final int expectedVersion;
  final String idempotencyKey;

  const _PendingPrompt({
    required this.content,
    required this.expectedVersion,
    required this.idempotencyKey,
  });
}
