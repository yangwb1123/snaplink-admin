part of 'agent_hub_api.dart';

class AgentHubApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const AgentHubApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isUnconfigured =>
      code == 'agent_hub_unconfigured' || code == 'hub_unconfigured';

  @override
  String toString() => message;
}

typedef AgentHubUnauthorizedHandler = void Function(AgentHubApiException error);
