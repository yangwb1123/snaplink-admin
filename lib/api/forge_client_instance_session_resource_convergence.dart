import 'dart:convert';

import 'forge_client_instance_resource_view.dart';
import 'forge_client_instance_session_view.dart';
import 'forge_device_inventory_declaration.dart';

/// Canonical read-only join of the owner-scoped client-instance session and
/// resource observations. The pair is a display projection only: it never
/// authenticates a session, mutates inventory, or grants execution authority.
const forgeClientInstanceSessionResourceConvergenceSchema =
    'forge.client-instance-session-resource-convergence/v1';
const forgeClientInstanceSessionResourceConvergenceEvaluationMode =
    'owner_bound_client_instance_session_resource_convergence_only';

class ForgeClientInstanceSessionResourceConvergenceAuthority {
  final bool ownerAuthenticated;
  final bool sessionReadAuthorized;
  final bool promptWriteAuthorized;
  final bool deviceIdentityVerified;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
    : ownerAuthenticated = false,
      sessionReadAuthorized = false,
      promptWriteAuthorized = false,
      deviceIdentityVerified = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeClientInstanceSessionResourceConvergenceAuthority.fromJson(
    Object? value,
  ) {
    final json = _convergenceObject(value, 'authority');
    _convergenceExactKeys(json, {
      'owner_authenticated',
      'session_read_authorized',
      'prompt_write_authorized',
      'device_identity_verified',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    if (json.values.any((value) => value != false)) {
      throw const FormatException(
        'Forge client-instance session/resource convergence authority must '
        'remain false.',
      );
    }
    return const ForgeClientInstanceSessionResourceConvergenceAuthority.offline();
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

class ForgeClientInstanceSessionResourceConvergence {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final ForgeClientInstanceSessionView sessionView;
  final ForgeClientInstanceResourceView resourceView;
  final bool converged;
  final bool readOnly;
  final ForgeClientInstanceSessionResourceConvergenceAuthority authority;

  const ForgeClientInstanceSessionResourceConvergence({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.sessionView,
    required this.resourceView,
    required this.converged,
    required this.readOnly,
    required this.authority,
  });

  factory ForgeClientInstanceSessionResourceConvergence.fromJson(
    Object? value,
  ) {
    final json = _convergenceObject(value, 'envelope');
    _convergenceExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'session_view',
      'resource_view',
      'converged',
      'read_only',
      'authority',
    });
    if (json['schema_version'] !=
            forgeClientInstanceSessionResourceConvergenceSchema ||
        json['evaluation_mode'] !=
            forgeClientInstanceSessionResourceConvergenceEvaluationMode ||
        json['converged'] != true ||
        json['read_only'] != true) {
      throw const FormatException(
        'Invalid Forge client-instance session/resource convergence envelope.',
      );
    }
    final sessionView = ForgeClientInstanceSessionView.fromJson(
      json['session_view'],
    );
    final resourceView = ForgeClientInstanceResourceView.fromJson(
      json['resource_view'],
    );
    if (sessionView.owner != resourceView.owner ||
        sessionView.ownerDeclarationUnverified !=
            resourceView.ownerDeclarationUnverified ||
        !_sameJson(sessionView.instances, resourceView.instances) ||
        !sessionView.isDisplayOnly ||
        !resourceView.isDisplayOnly) {
      throw const FormatException(
        'Forge client-instance session/resource observations did not converge.',
      );
    }
    final authority =
        ForgeClientInstanceSessionResourceConvergenceAuthority.fromJson(
          json['authority'],
        );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge client-instance session/resource convergence claims authority.',
      );
    }
    return ForgeClientInstanceSessionResourceConvergence(
      schemaVersion: forgeClientInstanceSessionResourceConvergenceSchema,
      evaluationMode:
          forgeClientInstanceSessionResourceConvergenceEvaluationMode,
      owner: sessionView.owner,
      sessionView: sessionView,
      resourceView: resourceView,
      converged: true,
      readOnly: true,
      authority: authority,
    );
  }

  factory ForgeClientInstanceSessionResourceConvergence.fromJsonText(
    String source,
  ) {
    try {
      if (utf8.encode(source).length > 4 * 1024 * 1024) {
        throw const FormatException(
          'Forge client-instance session/resource convergence is too large.',
        );
      }
      _convergenceRejectDuplicateKeys(source);
      return ForgeClientInstanceSessionResourceConvergence.fromJson(
        jsonDecode(source),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid Forge client-instance session/resource convergence JSON.',
      );
    }
  }

  bool get isDisplayOnly =>
      schemaVersion == forgeClientInstanceSessionResourceConvergenceSchema &&
      evaluationMode ==
          forgeClientInstanceSessionResourceConvergenceEvaluationMode &&
      converged &&
      readOnly &&
      authority.isOffline &&
      forgeClientInstanceSessionResourceObservationsConverged(
        sessionView,
        resourceView,
      );

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'session_view': sessionView.toJson(),
    'resource_view': resourceView.toJson(),
    'converged': converged,
    'read_only': readOnly,
    'authority': authority.toJson(),
  };
}

/// Compares two independently read client-instance observations before a
/// caller uses either one as a local filter. The resource view is allowed to
/// carry additional device rows, but its owner declaration and complete
/// instance image must be identical to the session view. This is a pure
/// display consistency check; it does not authenticate, schedule, or execute
/// work.
bool forgeClientInstanceSessionResourceObservationsConverged(
  ForgeClientInstanceSessionView sessionView,
  ForgeClientInstanceResourceView resourceView,
) {
  // Both observations can be supplied by an injected native/test reader.
  // Re-decode their typed JSON before accepting them as a local filter so a
  // hand-built row cannot bypass the strict owner, ordering, and field
  // invariants enforced at the transport boundary.
  late final ForgeClientInstanceSessionView validatedSessionView;
  late final ForgeClientInstanceResourceView validatedResourceView;
  try {
    validatedSessionView = ForgeClientInstanceSessionView.fromJson(
      sessionView.toJson(),
    );
    validatedResourceView = ForgeClientInstanceResourceView.fromJson(
      resourceView.toJson(),
    );
  } on FormatException {
    return false;
  }
  return validatedSessionView.isDisplayOnly &&
      validatedResourceView.isDisplayOnly &&
      validatedSessionView.owner == validatedResourceView.owner &&
      validatedSessionView.ownerDeclarationUnverified ==
          validatedResourceView.ownerDeclarationUnverified &&
      _sameJson(
        validatedSessionView.instances
            .map((instance) => instance.toJson())
            .toList(),
        validatedResourceView.instances
            .map((instance) => instance.toJson())
            .toList(),
      );
}

bool _sameJson(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);

Map<String, dynamic> _convergenceObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge client-instance session/resource convergence $label must be an object.',
    );
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _convergenceExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge client-instance session/resource convergence fields.',
    );
  }
}

void _convergenceRejectDuplicateKeys(String source) {
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
              'Duplicate Forge client-instance convergence JSON key.',
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
          'Invalid Forge client-instance convergence JSON.',
        );
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException(
      'Invalid Forge client-instance convergence JSON.',
    );
  }
}
