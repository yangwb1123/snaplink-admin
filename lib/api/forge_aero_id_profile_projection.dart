import 'dart:convert';

const forgeAeroIDProfileProjectionSchema =
    'forge.aero-id-profile-projection/v1';
const forgeAeroIDProfileProjectionEvaluationMode = 'pure_projection_only';
const forgeAeroIDProfileProjectionSource = 'aero-id';
const forgeAeroIDProfileProjectionNotice =
    'This is a caller-supplied Aero-ID profile/membership projection. Owner, account, profile, membership, consistency, and status values are unverified; it grants no Forge authorization, device, reservation, scheduling, dispatch, or execution authority.';
const _forgeAeroIDProfileProjectionMaxMemberships = 128;

class ForgeAeroIDProfileProjectionOwner {
  final String issuer;
  final String subject;
  final String tenantID;

  const ForgeAeroIDProfileProjectionOwner({
    required this.issuer,
    required this.subject,
    required this.tenantID,
  });

  factory ForgeAeroIDProfileProjectionOwner.fromJson(Object? value) {
    final json = _aeroObject(value, 'owner');
    _aeroExactKeys(json, {'issuer', 'subject', 'tenant_id'});
    final owner = ForgeAeroIDProfileProjectionOwner(
      issuer: _aeroText(json['issuer'], 'owner issuer'),
      subject: _aeroText(json['subject'], 'owner subject'),
      tenantID: _aeroText(json['tenant_id'], 'owner tenant'),
    );
    _aeroValidateOwner(owner);
    return owner;
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeAeroIDProfileProjectionOwner &&
      issuer == other.issuer &&
      subject == other.subject &&
      tenantID == other.tenantID;

  @override
  int get hashCode => Object.hash(issuer, subject, tenantID);
}

class ForgeAeroIDProfileProjectionProfile {
  final String accountID;
  final String displayName;
  final String avatarURL;
  final String locale;
  final String timezone;

  const ForgeAeroIDProfileProjectionProfile({
    required this.accountID,
    required this.displayName,
    required this.avatarURL,
    required this.locale,
    required this.timezone,
  });

  factory ForgeAeroIDProfileProjectionProfile.fromJson(Object? value) {
    final json = _aeroObject(value, 'profile');
    _aeroExactKeys(json, {
      'account_id',
      'display_name',
      'avatar_url',
      'locale',
      'timezone',
    });
    final profile = ForgeAeroIDProfileProjectionProfile(
      accountID: _aeroText(json['account_id'], 'profile account ID'),
      displayName: _aeroText(
        json['display_name'],
        'profile display name',
        allowEmpty: true,
      ),
      avatarURL: _aeroText(
        json['avatar_url'],
        'profile avatar URL',
        maxBytes: 2048,
        allowEmpty: true,
      ),
      locale: _aeroText(json['locale'], 'profile locale', allowEmpty: true),
      timezone: _aeroText(
        json['timezone'],
        'profile timezone',
        allowEmpty: true,
      ),
    );
    if (profile.accountID.length > 128 ||
        utf8.encode(profile.displayName).length > 512 ||
        utf8.encode(profile.locale).length > 128 ||
        utf8.encode(profile.timezone).length > 128) {
      throw const FormatException('Aero-ID profile fields are too long.');
    }
    return profile;
  }
}

class ForgeAeroIDProfileProjectionMembership {
  final String source;
  final String scopeType;
  final String scopeID;
  final String role;
  final String status;

  const ForgeAeroIDProfileProjectionMembership({
    required this.source,
    required this.scopeType,
    required this.scopeID,
    required this.role,
    required this.status,
  });

  factory ForgeAeroIDProfileProjectionMembership.fromJson(Object? value) {
    final json = _aeroObject(value, 'membership');
    _aeroExactKeys(json, {
      'source',
      'scope_type',
      'scope_id',
      'role',
      'status',
    });
    return ForgeAeroIDProfileProjectionMembership(
      source: _aeroText(json['source'], 'membership source'),
      scopeType: _aeroText(json['scope_type'], 'membership scope type'),
      scopeID: _aeroText(
        json['scope_id'],
        'membership scope ID',
        maxBytes: 256,
      ),
      role: _aeroText(json['role'], 'membership role'),
      status: _aeroText(json['status'], 'membership status'),
    );
  }

  String get _sortKey =>
      '$source\u0000$scopeType\u0000$scopeID\u0000$role\u0000$status';
}

class ForgeAeroIDProfileProjectionAuthority {
  final bool identityVerified;
  final bool profileAuthoritative;
  final bool membershipAuthoritative;
  final bool authorizationGranted;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeAeroIDProfileProjectionAuthority({
    required this.identityVerified,
    required this.profileAuthoritative,
    required this.membershipAuthoritative,
    required this.authorizationGranted,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  factory ForgeAeroIDProfileProjectionAuthority.fromJson(Object? value) {
    final json = _aeroObject(value, 'authority');
    _aeroExactKeys(json, {
      'identity_verified',
      'profile_authoritative',
      'membership_authoritative',
      'authorization_granted',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    return ForgeAeroIDProfileProjectionAuthority(
      identityVerified: _aeroBool(json['identity_verified'], 'identity'),
      profileAuthoritative: _aeroBool(json['profile_authoritative'], 'profile'),
      membershipAuthoritative: _aeroBool(
        json['membership_authoritative'],
        'membership',
      ),
      authorizationGranted: _aeroBool(
        json['authorization_granted'],
        'authorization',
      ),
      executionAuthorized: _aeroBool(json['execution_authorized'], 'execution'),
      reservationCreated: _aeroBool(json['reservation_created'], 'reservation'),
      dispatchPerformed: _aeroBool(json['dispatch_performed'], 'dispatch'),
    );
  }

  bool get isAllFalse =>
      !identityVerified &&
      !profileAuthoritative &&
      !membershipAuthoritative &&
      !authorizationGranted &&
      !executionAuthorized &&
      !reservationCreated &&
      !dispatchPerformed;
}

class ForgeAeroIDProfileProjection {
  final ForgeAeroIDProfileProjectionOwner owner;
  final ForgeAeroIDProfileProjectionProfile profile;
  final List<ForgeAeroIDProfileProjectionMembership> memberships;
  final String consistency;
  final bool partial;
  final ForgeAeroIDProfileProjectionAuthority authority;

  const ForgeAeroIDProfileProjection({
    required this.owner,
    required this.profile,
    required this.memberships,
    required this.consistency,
    required this.partial,
    required this.authority,
  });

  factory ForgeAeroIDProfileProjection.fromJson(Object? value) {
    final json = _aeroObject(value, 'projection');
    _aeroExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source',
      'owner_declaration',
      'owner_declaration_unverified',
      'profile_attributes_unverified',
      'membership_attributes_unverified',
      'profile',
      'memberships',
      'consistency',
      'partial',
      'notice',
      'authority',
    });
    if (json['schema_version'] != forgeAeroIDProfileProjectionSchema ||
        json['evaluation_mode'] != forgeAeroIDProfileProjectionEvaluationMode ||
        json['source'] != forgeAeroIDProfileProjectionSource ||
        json['notice'] != forgeAeroIDProfileProjectionNotice ||
        json['owner_declaration_unverified'] != true ||
        json['profile_attributes_unverified'] != true ||
        json['membership_attributes_unverified'] != true) {
      throw const FormatException('Invalid Aero-ID projection envelope.');
    }
    final membershipsValue = json['memberships'];
    if (membershipsValue is! List ||
        membershipsValue.length > _forgeAeroIDProfileProjectionMaxMemberships) {
      throw const FormatException('Invalid Aero-ID projection memberships.');
    }
    final memberships = membershipsValue
        .map(ForgeAeroIDProfileProjectionMembership.fromJson)
        .toList(growable: false);
    final seen = <String>{};
    String? previous;
    for (final membership in memberships) {
      if (!seen.add(membership._sortKey) ||
          (previous != null && previous.compareTo(membership._sortKey) >= 0)) {
        throw const FormatException(
          'Aero-ID projection memberships are not sorted.',
        );
      }
      previous = membership._sortKey;
    }
    final consistency = _aeroText(json['consistency'], 'consistency');
    if (!{'eventual', 'bounded', 'strong'}.contains(consistency)) {
      throw const FormatException('Invalid Aero-ID projection consistency.');
    }
    final authority = ForgeAeroIDProfileProjectionAuthority.fromJson(
      json['authority'],
    );
    if (!authority.isAllFalse) {
      throw const FormatException('Aero-ID projection claims authority.');
    }
    return ForgeAeroIDProfileProjection(
      owner: ForgeAeroIDProfileProjectionOwner.fromJson(
        json['owner_declaration'],
      ),
      profile: ForgeAeroIDProfileProjectionProfile.fromJson(json['profile']),
      memberships: memberships,
      consistency: consistency,
      partial: _aeroBool(json['partial'], 'partial'),
      authority: authority,
    );
  }

  void bindOwner(ForgeAeroIDProfileProjectionOwner expected) {
    if (owner != expected) {
      throw const FormatException('Aero-ID projection owner does not match.');
    }
  }
}

Map<String, dynamic> _aeroObject(Object? value, String label) {
  if (value is! Map) throw FormatException('Expected Aero-ID $label object.');
  return Map<String, dynamic>.from(value);
}

void _aeroExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Aero-ID projection fields.');
  }
}

String _aeroText(
  Object? value,
  String label, {
  int maxBytes = 128,
  bool allowEmpty = false,
}) {
  if (value is! String ||
      (!allowEmpty && value.isEmpty) ||
      value.trim() != value ||
      utf8.encode(value).length > maxBytes ||
      value.runes.any(
        (rune) =>
            rune < 0x20 ||
            rune == 0x7f ||
            (rune >= 0x80 && rune <= 0x9f),
      )) {
    throw FormatException('Invalid Aero-ID projection $label.');
  }
  return value;
}

bool _aeroBool(Object? value, String label) {
  if (value is! bool) {
    throw FormatException('Invalid Aero-ID projection $label.');
  }
  return value;
}

void _aeroValidateOwner(ForgeAeroIDProfileProjectionOwner owner) {
  _aeroText(owner.issuer, 'owner issuer', maxBytes: 256);
  _aeroText(owner.subject, 'owner subject', maxBytes: 256);
  _aeroText(owner.tenantID, 'owner tenant', maxBytes: 256);
}
