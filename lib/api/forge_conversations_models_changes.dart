part of 'forge_conversations_models.dart';

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
    final aggregateVersion = _requiredPositiveInt(json, 'aggregate_version');
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    if (cursor > _maxSafeForgeCursor ||
        schemaVersion > _maxSafeForgeCursor ||
        aggregateVersion > _maxSafeForgeCursor ||
        createdAtMS > _maxSafeForgeCursor ||
        !_validFeedID(conversationID) ||
        !_validFeedID(entityID) ||
        (kind == 'conversation_created' && entityID != conversationID)) {
      throw const FormatException('Invalid Forge conversation change IDs.');
    }
    return ForgeConversationChange(
      cursor: cursor,
      schemaVersion: schemaVersion,
      conversationID: conversationID,
      entityID: entityID,
      aggregateVersion: aggregateVersion,
      kind: kind,
      createdAtMS: createdAtMS,
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
