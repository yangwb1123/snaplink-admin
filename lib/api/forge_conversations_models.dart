import 'dart:convert';

part 'forge_conversations_models_prompts.dart';
part 'forge_conversations_models_runs.dart';
part 'forge_conversations_models_prompt_validation.dart';
part 'forge_conversations_models_changes.dart';

typedef ForgeJson = Map<String, dynamic>;

const _maxSafeForgeCursor = 9007199254740991;
const _maxForgePromptIDBytes = 128;
const _maxForgePromptRoleBytes = 64;
const _maxForgePromptContentBytes = 256 * 1024;
const _maxForgeConversationPageSize = 128;
const _maxForgePromptPageSize = 128;
const _maxForgeRunPageSize = 25;
const _maxForgeRunTimelinePageSize = 128;
const _maxForgeExecutionConsentTTLMS = 30 * 24 * 60 * 60 * 1000;

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
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    final updatedAtMS = _requiredNonNegativeInt(json, 'updated_at_ms');
    final conversation = ForgeConversation(
      id: _requiredExactText(json, 'id'),
      scope: ForgeConversationScope.fromJson(_requiredObject(json, 'scope')),
      title: _requiredExactText(json, 'title'),
      createdAtMS: createdAtMS,
      updatedAtMS: updatedAtMS,
    );
    if (!_validConversationID(conversation.id) ||
        conversation.title.trim().isEmpty ||
        updatedAtMS < createdAtMS ||
        createdAtMS > _maxSafeForgeCursor ||
        updatedAtMS > _maxSafeForgeCursor) {
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

/// The read-only execution-consent preview returned for one owned
/// Conversation. This candidate is metadata only: it does not grant consent,
/// create a Run, select a device, or release execution authority.
///
/// Keep this DTO closed because the preview is also the exact input contract
/// for the later explicit consent confirmation. Unknown fields must not be
/// silently carried into a confirmation flow.
class ForgeExecutionConsentPreview {
  final String conversationID;
  final String projectID;
  final String profileID;
  final String profileSHA256;
  final int maximumTTLMS;

  const ForgeExecutionConsentPreview({
    required this.conversationID,
    required this.projectID,
    required this.profileID,
    required this.profileSHA256,
    required this.maximumTTLMS,
  });

  factory ForgeExecutionConsentPreview.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'conversation_id',
      'project_id',
      'profile_id',
      'profile_sha256',
      'maximum_ttl_ms',
    });
    final conversationID = _requiredExactText(json, 'conversation_id');
    final projectID = _requiredExactText(json, 'project_id');
    final profileID = _requiredExactText(json, 'profile_id');
    final profileSHA256 = _requiredExactText(json, 'profile_sha256');
    final maximumTTLMS = _requiredPositiveInt(json, 'maximum_ttl_ms');
    if (!_validConversationID(conversationID) ||
        !_validConversationID(projectID) ||
        !_validConversationID(profileID) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(profileSHA256) ||
        maximumTTLMS > _maxForgeExecutionConsentTTLMS) {
      throw const FormatException('Invalid Forge execution consent preview.');
    }
    return ForgeExecutionConsentPreview(
      conversationID: conversationID,
      projectID: projectID,
      profileID: profileID,
      profileSHA256: profileSHA256,
      maximumTTLMS: maximumTTLMS,
    );
  }

  ForgeJson toJson() => {
    'conversation_id': conversationID,
    'project_id': projectID,
    'profile_id': profileID,
    'profile_sha256': profileSHA256,
    'maximum_ttl_ms': maximumTTLMS,
  };
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
    _requireExactKeys(json, const {'prompt', 'aggregate_version', 'replayed'});
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
  if (value is! int || value < 1 || value > _maxSafeForgeCursor) {
    throw FormatException('Invalid Forge response field: $key.');
  }
  return value;
}
