import 'dart:convert';

class ConsentScopeDescriptor {
  final String scope;
  final String description;

  const ConsentScopeDescriptor({required this.scope, this.description = ''});
}

/// A fail-closed rendering model for a `consent_required` response.
class ConsentRequestSummary {
  final List<ConsentScopeDescriptor> scopes;
  final List<Map<String, dynamic>> authorizationDetails;
  final String? parseError;

  const ConsentRequestSummary({
    required this.scopes,
    required this.authorizationDetails,
    this.parseError,
  });

  const ConsentRequestSummary.invalid([this.parseError = consentSummaryError])
    : scopes = const [],
      authorizationDetails = const [];

  static const consentSummaryError =
      'The authorization request could not be summarized safely.';

  factory ConsentRequestSummary.fromResponse(Map<String, dynamic> response) {
    final parsedScopes = <ConsentScopeDescriptor>[];
    final rawScopes = response['scopes'];
    if (rawScopes is! List) {
      return const ConsentRequestSummary.invalid();
    }
    for (final rawScope in rawScopes) {
      if (rawScope is String) {
        final scope = rawScope.trim();
        if (scope.isEmpty) {
          return const ConsentRequestSummary.invalid();
        }
        parsedScopes.add(ConsentScopeDescriptor(scope: scope));
        continue;
      }
      if (rawScope is! Map) {
        return const ConsentRequestSummary.invalid();
      }
      final scope = rawScope['scope']?.toString().trim() ?? '';
      if (scope.isEmpty) {
        return const ConsentRequestSummary.invalid();
      }
      parsedScopes.add(
        ConsentScopeDescriptor(
          scope: scope,
          description: rawScope['description']?.toString().trim() ?? '',
        ),
      );
    }

    final parsedDetails = <Map<String, dynamic>>[];
    if (response.containsKey('authorization_details')) {
      Object? rawDetails = response['authorization_details'];
      if (rawDetails is String) {
        try {
          rawDetails = jsonDecode(rawDetails);
        } on FormatException {
          return const ConsentRequestSummary.invalid();
        }
      }
      if (rawDetails is! List || rawDetails.isEmpty) {
        return const ConsentRequestSummary.invalid();
      }
      for (final rawDetail in rawDetails) {
        if (rawDetail is! Map || rawDetail.isEmpty) {
          return const ConsentRequestSummary.invalid();
        }
        parsedDetails.add({
          for (final entry in rawDetail.entries)
            entry.key.toString(): entry.value,
        });
      }
    }

    final summary = ConsentRequestSummary(
      scopes: List.unmodifiable(parsedScopes),
      authorizationDetails: List.unmodifiable(parsedDetails),
    );
    if (!summary.hasTerms) {
      return const ConsentRequestSummary.invalid(
        'The authorization request contains no permissions to review.',
      );
    }
    return summary;
  }

  bool get hasTerms => scopes.isNotEmpty || authorizationDetails.isNotEmpty;

  bool get canAuthorize => parseError == null && hasTerms;
}
