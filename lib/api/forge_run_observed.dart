import 'dart:convert';

/// Strict consumer for the shared content-free Forge Run observer value.
///
/// This is a display/evidence value only. It does not authenticate the owner,
/// authorize a Run, read a service, or imply persistence, reservation,
/// dispatch, or execution.

const forgeRunObservedSchema = 'forge.run.observed.v1';
const forgeRunObservedMaxSafeInteger = 9007199254740991;

class ForgeRunObservedAuthority {
  final bool identityVerified;
  final bool ownerAuthorized;
  final bool runAuthoritative;
  final bool persistenceAttested;
  final bool contentProvenanceVerified;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeRunObservedAuthority({
    required this.identityVerified,
    required this.ownerAuthorized,
    required this.runAuthoritative,
    required this.persistenceAttested,
    required this.contentProvenanceVerified,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  const ForgeRunObservedAuthority.offline()
    : identityVerified = false,
      ownerAuthorized = false,
      runAuthoritative = false,
      persistenceAttested = false,
      contentProvenanceVerified = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false;

  bool get isAllFalse =>
      !identityVerified &&
      !ownerAuthorized &&
      !runAuthoritative &&
      !persistenceAttested &&
      !contentProvenanceVerified &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed;

  factory ForgeRunObservedAuthority.fromJson(Object? value) {
    final json = _object(value, 'authority');
    _exactKeys(json, const {
      'identity_verified',
      'owner_authorized',
      'run_authoritative',
      'persistence_attested',
      'content_provenance_verified',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final result = ForgeRunObservedAuthority(
      identityVerified: _bool(json['identity_verified'], 'identity_verified'),
      ownerAuthorized: _bool(json['owner_authorized'], 'owner_authorized'),
      runAuthoritative: _bool(json['run_authoritative'], 'run_authoritative'),
      persistenceAttested: _bool(
        json['persistence_attested'],
        'persistence_attested',
      ),
      contentProvenanceVerified: _bool(
        json['content_provenance_verified'],
        'content_provenance_verified',
      ),
      reservationCreated: _bool(
        json['reservation_created'],
        'reservation_created',
      ),
      executionAuthorized: _bool(
        json['execution_authorized'],
        'execution_authorized',
      ),
      dispatchPerformed: _bool(
        json['dispatch_performed'],
        'dispatch_performed',
      ),
    );
    if (!result.isAllFalse) {
      throw const FormatException(
        'Forge Run observer authority must remain disabled.',
      );
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'owner_authorized': ownerAuthorized,
    'run_authoritative': runAuthoritative,
    'persistence_attested': persistenceAttested,
    'content_provenance_verified': contentProvenanceVerified,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeRunObserved {
  final String ownerRef;
  final String conversationID;
  final String runID;
  final String promptID;
  final int createdAtMS;
  final int latestSequence;
  final String status;
  final bool metadataObserved;
  final bool contentIncluded;
  final ForgeRunObservedAuthority authority;

  const ForgeRunObserved({
    required this.ownerRef,
    required this.conversationID,
    required this.runID,
    required this.promptID,
    required this.createdAtMS,
    required this.latestSequence,
    required this.status,
    required this.metadataObserved,
    required this.contentIncluded,
    required this.authority,
  });

  /// Decodes one bounded raw JSON document before Dart map conversion so
  /// duplicate object names cannot be silently replaced by `jsonDecode`.
  factory ForgeRunObserved.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException('Forge Run observer document is too large.');
    }
    _runObservedRejectDuplicateKeys(source);
    return ForgeRunObserved.fromJson(jsonDecode(source));
  }

  factory ForgeRunObserved.fromJson(Object? value) {
    final json = _object(value, 'Forge Run observer');
    _exactKeys(json, const {
      'api_version',
      'owner_ref',
      'conversation_id',
      'run_id',
      'prompt_id',
      'created_at_ms',
      'latest_sequence',
      'status',
      'metadata_observed',
      'content_included',
      'authority',
    });
    final createdAtMS = _safeInt(json['created_at_ms'], 'created_at_ms');
    final latestSequence = _safeInt(json['latest_sequence'], 'latest_sequence');
    final status = _text(json['status'], 'status');
    final metadataObserved = _bool(
      json['metadata_observed'],
      'metadata_observed',
    );
    final contentIncluded = _bool(json['content_included'], 'content_included');
    if (_text(json['api_version'], 'api_version') != forgeRunObservedSchema ||
        !_sha256(_text(json['owner_ref'], 'owner_ref')) ||
        !_identifier(json['conversation_id'], 'conversation_id') ||
        !_identifier(json['run_id'], 'run_id') ||
        !_identifier(json['prompt_id'], 'prompt_id') ||
        createdAtMS < 0 ||
        latestSequence < 1 ||
        !_statuses.contains(status) ||
        !metadataObserved ||
        contentIncluded) {
      throw const FormatException('Invalid Forge Run observer value.');
    }
    return ForgeRunObserved(
      ownerRef: _text(json['owner_ref'], 'owner_ref'),
      conversationID: _text(json['conversation_id'], 'conversation_id'),
      runID: _text(json['run_id'], 'run_id'),
      promptID: _text(json['prompt_id'], 'prompt_id'),
      createdAtMS: createdAtMS,
      latestSequence: latestSequence,
      status: status,
      metadataObserved: metadataObserved,
      contentIncluded: contentIncluded,
      authority: ForgeRunObservedAuthority.fromJson(json['authority']),
    );
  }

  Map<String, dynamic> toJson() => {
    'api_version': forgeRunObservedSchema,
    'owner_ref': ownerRef,
    'conversation_id': conversationID,
    'run_id': runID,
    'prompt_id': promptID,
    'created_at_ms': createdAtMS,
    'latest_sequence': latestSequence,
    'status': status,
    'metadata_observed': metadataObserved,
    'content_included': contentIncluded,
    'authority': authority.toJson(),
  };

  /// Returns whether this caller-supplied projection belongs to the selected
  /// Conversation and Run. The owner reference is intentionally only a
  /// digest, so a screen never derives an owner identity from it.
  bool isFor(String selectedConversationID, String selectedRunID) =>
      conversationID == selectedConversationID && runID == selectedRunID;

  /// Run observer values are metadata-only evidence. This predicate keeps
  /// the display boundary explicit for injected values.
  bool get isDisplayOnly =>
      metadataObserved && !contentIncluded && authority.isAllFalse;
}

const _statuses = {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
};

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('Expected $label object.');
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge Run observer fields.');
  }
}

String _text(Object? value, String label) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('Invalid Forge Run observer $label.');
  }
  return value;
}

bool _bool(Object? value, String label) {
  if (value is! bool) {
    throw FormatException('Invalid Forge Run observer $label.');
  }
  return value;
}

int _safeInt(Object? value, String label) {
  if (value is! int || value < 0 || value > forgeRunObservedMaxSafeInteger) {
    throw FormatException('Invalid Forge Run observer $label.');
  }
  return value;
}

bool _identifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length != value.trim().length) {
    return false;
  }
  final bytes = utf8.encode(value).length;
  return bytes <= 85 && !value.runes.any(_forbiddenIdentifierRune);
}

bool _forbiddenIdentifierRune(int rune) {
  if (rune < 0x20 ||
      (rune >= 0x7f && rune <= 0x9f) ||
      rune == 0x3a ||
      rune == 0x2f ||
      rune == 0x5c) {
    return true;
  }
  final character = String.fromCharCodes([rune]);
  return character.trim().isEmpty;
}

bool _sha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

void _runObservedRejectDuplicateKeys(String source) {
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
        while (next < source.length && _runObservedWhitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge Run observer object.');
          }
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge Run observer JSON key.',
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
        throw const FormatException('Invalid Forge Run observer object.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge Run observer JSON.');
  }
}

bool _runObservedWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
