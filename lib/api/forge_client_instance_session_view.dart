import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

/// Strict, read-only metadata for the sessions visible from independent Forge
/// client instances. This value never authenticates an owner, writes a
/// Prompt, creates a Run, contacts Agent Hub, or identifies a Runner/device.
const forgeClientInstanceSessionViewSchema =
    'forge.client-instance-session-view/v1';
const forgeClientInstanceSessionViewEvaluationMode =
    'owner_bound_session_view_only';
const forgeClientInstanceSessionViewMaxInstances = 128;
const forgeClientInstanceSessionViewMaxSessionIDs = 128;
const forgeClientInstanceSessionViewMaxSafeInteger = 9007199254740991;
const _forgeClientInstanceSessionViewMaxInputBytes = 2 * 1024 * 1024;

/// Reads one bounded local client-instance/session-view document.
///
/// The callback only supplies source text; callers must still use the strict
/// decoder below, and the value carries no network or execution authority.
typedef ForgeClientInstanceSessionViewFileReader = Future<String?> Function();

const _forgeClientInstanceKinds = {'cli', 'tui', 'web', 'app', 'mobile'};
const _forgeClientInstanceStatuses = {'active', 'idle', 'offline', 'unknown'};

class ForgeClientInstanceSessionViewAuthority {
  final bool ownerAuthenticated;
  final bool sessionReadAuthorized;
  final bool promptWriteAuthorized;
  final bool deviceIdentityVerified;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeClientInstanceSessionViewAuthority.offline()
    : ownerAuthenticated = false,
      sessionReadAuthorized = false,
      promptWriteAuthorized = false,
      deviceIdentityVerified = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeClientInstanceSessionViewAuthority.fromJson(Object? value) {
    final json = _clientSessionViewObject(value, 'authority');
    _clientSessionViewExactKeys(json, {
      'owner_authenticated',
      'session_read_authorized',
      'prompt_write_authorized',
      'device_identity_verified',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    for (final entry in json.entries) {
      if (entry.value is! bool || entry.value == true) {
        throw const FormatException(
          'Forge client-instance/session-view authority must remain false.',
        );
      }
    }
    return const ForgeClientInstanceSessionViewAuthority.offline();
  }

  bool get isOffline =>
      !ownerAuthenticated &&
      !sessionReadAuthorized &&
      !promptWriteAuthorized &&
      !deviceIdentityVerified &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'owner_authenticated': ownerAuthenticated,
    'session_read_authorized': sessionReadAuthorized,
    'prompt_write_authorized': promptWriteAuthorized,
    'device_identity_verified': deviceIdentityVerified,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeClientInstanceSessionViewInstance {
  final String instanceID;
  final String clientKind;
  final List<String> sessionIDs;
  final int observedAtMS;
  final String status;

  const ForgeClientInstanceSessionViewInstance({
    required this.instanceID,
    required this.clientKind,
    required this.sessionIDs,
    required this.observedAtMS,
    required this.status,
  });

  factory ForgeClientInstanceSessionViewInstance.fromJson(Object? value) {
    final json = _clientSessionViewObject(value, 'instance');
    _clientSessionViewExactKeys(json, {
      'instance_id',
      'client_kind',
      'session_ids',
      'observed_at_ms',
      'status',
    });
    final rawSessionIDs = json['session_ids'];
    if (rawSessionIDs is! List ||
        rawSessionIDs.length > forgeClientInstanceSessionViewMaxSessionIDs) {
      throw const FormatException(
        'Invalid Forge client-instance/session-view session IDs.',
      );
    }
    final sessionIDs = rawSessionIDs
        .map((value) => _clientSessionViewIdentifier(value, 'session ID'))
        .toList(growable: false);
    for (var index = 1; index < sessionIDs.length; index++) {
      if (sessionIDs[index - 1].compareTo(sessionIDs[index]) >= 0) {
        throw const FormatException(
          'Forge client-instance/session-view session IDs must be sorted and unique.',
        );
      }
    }
    return ForgeClientInstanceSessionViewInstance(
      instanceID: _clientSessionViewIdentifier(
        json['instance_id'],
        'instance ID',
      ),
      clientKind: _clientSessionViewOneOf(
        json['client_kind'],
        _forgeClientInstanceKinds,
        'client kind',
      ),
      sessionIDs: List.unmodifiable(sessionIDs),
      observedAtMS: _clientSessionViewPositiveSafeInteger(
        json['observed_at_ms'],
        'observed_at_ms',
      ),
      status: _clientSessionViewOneOf(
        json['status'],
        _forgeClientInstanceStatuses,
        'status',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'instance_id': instanceID,
    'client_kind': clientKind,
    'session_ids': sessionIDs,
    'observed_at_ms': observedAtMS,
    'status': status,
  };
}

class ForgeClientInstanceSessionView {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final List<ForgeClientInstanceSessionViewInstance> instances;
  final bool readOnly;
  final ForgeClientInstanceSessionViewAuthority authority;

  const ForgeClientInstanceSessionView({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.instances,
    required this.readOnly,
    required this.authority,
  });

  factory ForgeClientInstanceSessionView.fromJson(Object? value) {
    final json = _clientSessionViewObject(value, 'fixture');
    _clientSessionViewExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner_declaration',
      'owner_declaration_unverified',
      'instances',
      'read_only',
      'authority',
    });
    if (json['schema_version'] != forgeClientInstanceSessionViewSchema ||
        json['evaluation_mode'] !=
            forgeClientInstanceSessionViewEvaluationMode ||
        json['owner_declaration_unverified'] != true ||
        json['read_only'] != true) {
      throw const FormatException(
        'Invalid Forge client-instance/session-view envelope.',
      );
    }
    final rawInstances = json['instances'];
    if (rawInstances is! List ||
        rawInstances.length > forgeClientInstanceSessionViewMaxInstances) {
      throw const FormatException(
        'Invalid Forge client-instance/session-view instances.',
      );
    }
    final instances = rawInstances
        .map(ForgeClientInstanceSessionViewInstance.fromJson)
        .toList(growable: false);
    final instanceIDs = <String>{};
    for (var index = 0; index < instances.length; index++) {
      final instance = instances[index];
      if (!instanceIDs.add(instance.instanceID) ||
          (index > 0 &&
              instances[index - 1].instanceID.compareTo(instance.instanceID) >=
                  0)) {
        throw const FormatException(
          'Forge client-instance/session-view instances must be sorted and unique.',
        );
      }
    }
    final fixture = ForgeClientInstanceSessionView(
      schemaVersion: forgeClientInstanceSessionViewSchema,
      evaluationMode: forgeClientInstanceSessionViewEvaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner_declaration']),
      ownerDeclarationUnverified: true,
      instances: List.unmodifiable(instances),
      readOnly: true,
      authority: ForgeClientInstanceSessionViewAuthority.fromJson(
        json['authority'],
      ),
    );
    if (!fixture.authority.isOffline) {
      throw const FormatException(
        'Forge client-instance/session-view fixture claims authority.',
      );
    }
    return fixture;
  }

  factory ForgeClientInstanceSessionView.fromJsonText(String source) {
    try {
      if (utf8.encode(source).length >
          _forgeClientInstanceSessionViewMaxInputBytes) {
        throw const FormatException(
          'Forge client-instance/session-view fixture is too large.',
        );
      }
      _clientSessionViewRejectDuplicateKeys(source);
      return ForgeClientInstanceSessionView.fromJson(jsonDecode(source));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid Forge client-instance/session-view JSON.',
      );
    }
  }

  bool get isDisplayOnly =>
      schemaVersion == forgeClientInstanceSessionViewSchema &&
      evaluationMode == forgeClientInstanceSessionViewEvaluationMode &&
      ownerDeclarationUnverified &&
      readOnly &&
      authority.isOffline;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner_declaration': owner.toJson(),
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'instances': instances.map((instance) => instance.toJson()).toList(),
    'read_only': readOnly,
    'authority': authority.toJson(),
  };
}

Map<String, dynamic> _clientSessionViewObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge client-instance/session-view $label must be an object.',
    );
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _clientSessionViewExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge client-instance/session-view fields.',
    );
  }
}

String _clientSessionViewIdentifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_clientSessionViewASCIIIdentifier(value)) {
    throw FormatException('Invalid Forge client-instance/session-view $label.');
  }
  return value;
}

bool _clientSessionViewASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d, 0x2b, 0x2f].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

String _clientSessionViewOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Invalid Forge client-instance/session-view $label.');
  }
  return value;
}

int _clientSessionViewPositiveSafeInteger(Object? value, String label) {
  if (value is! int ||
      value <= 0 ||
      value > forgeClientInstanceSessionViewMaxSafeInteger) {
    throw FormatException('Invalid Forge client-instance/session-view $label.');
  }
  return value;
}

void _clientSessionViewRejectDuplicateKeys(String source) {
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
              'Duplicate Forge client-instance/session-view JSON key.',
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
        throw const FormatException(
          'Invalid Forge client-instance/session-view JSON.',
        );
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException(
      'Invalid Forge client-instance/session-view JSON.',
    );
  }
}
