import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';

part 'forge_prompt_append_receipt_validation.dart';

const forgePromptAppendReceiptSchema = 'forge.prompt-append-receipt/v1';
const forgePromptAppendReceiptMaxSafeInteger = 9007199254740991;
const forgePromptAppendReceiptMaxInputBytes = 2 * 1024 * 1024;
const forgePromptAppendReceiptMaxContentBytes = 256 * 1024;
const forgePromptAppendReceiptMaxIdempotencyKeyBytes = 256;

class ForgePromptAppendReceiptAuthority {
  final bool runCreated;
  final bool deviceSelected;
  final bool reservationCreated;
  final bool dispatchPerformed;
  final bool executionAuthorized;
  final bool auditPublished;

  const ForgePromptAppendReceiptAuthority({
    required this.runCreated,
    required this.deviceSelected,
    required this.reservationCreated,
    required this.dispatchPerformed,
    required this.executionAuthorized,
    required this.auditPublished,
  });

  factory ForgePromptAppendReceiptAuthority.fromJson(Object? value) {
    final json = _promptAppendObject(value, 'authority');
    _promptAppendExactKeys(json, {
      'run_created',
      'device_selected',
      'reservation_created',
      'dispatch_performed',
      'execution_authorized',
      'audit_published',
    }, 'authority');
    final result = ForgePromptAppendReceiptAuthority(
      runCreated: _promptAppendBool(json['run_created'], 'run_created'),
      deviceSelected: _promptAppendBool(
        json['device_selected'],
        'device_selected',
      ),
      reservationCreated: _promptAppendBool(
        json['reservation_created'],
        'reservation_created',
      ),
      dispatchPerformed: _promptAppendBool(
        json['dispatch_performed'],
        'dispatch_performed',
      ),
      executionAuthorized: _promptAppendBool(
        json['execution_authorized'],
        'execution_authorized',
      ),
      auditPublished: _promptAppendBool(
        json['audit_published'],
        'audit_published',
      ),
    );
    if (!result.isClear) {
      throw const FormatException(
        'Prompt append receipt claims downstream authority.',
      );
    }
    return result;
  }

  bool get isClear =>
      !runCreated &&
      !deviceSelected &&
      !reservationCreated &&
      !dispatchPerformed &&
      !executionAuthorized &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'run_created': runCreated,
    'device_selected': deviceSelected,
    'reservation_created': reservationCreated,
    'dispatch_performed': dispatchPerformed,
    'execution_authorized': executionAuthorized,
    'audit_published': auditPublished,
  };
}

class ForgePromptAppendReceiptRequest {
  final String conversationID;
  final int expectedVersion;
  final String role;
  final String contentSHA256;
  final String idempotencyKeySHA256;

  const ForgePromptAppendReceiptRequest({
    required this.conversationID,
    required this.expectedVersion,
    required this.role,
    required this.contentSHA256,
    required this.idempotencyKeySHA256,
  });

  factory ForgePromptAppendReceiptRequest.fromJson(Object? value) {
    final json = _promptAppendObject(value, 'request');
    _promptAppendExactKeys(json, {
      'conversation_id',
      'expected_version',
      'role',
      'content_sha256',
      'idempotency_key_sha256',
    }, 'request');
    return ForgePromptAppendReceiptRequest(
      conversationID: _promptAppendIdentifier(
        json['conversation_id'],
        'conversation_id',
      ),
      expectedVersion: _promptAppendPositiveInt(
        json['expected_version'],
        'expected_version',
      ),
      role: _promptAppendRole(json['role']),
      contentSHA256: _promptAppendDigest(
        json['content_sha256'],
        'content_sha256',
      ),
      idempotencyKeySHA256: _promptAppendDigest(
        json['idempotency_key_sha256'],
        'idempotency_key_sha256',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'expected_version': expectedVersion,
    'role': role,
    'content_sha256': contentSHA256,
    'idempotency_key_sha256': idempotencyKeySHA256,
  };
}

class ForgePromptAppendReceipt {
  final String conversationID;
  final String promptID;
  final String role;
  final int aggregateVersion;
  final int createdAtMS;
  final bool replayed;
  final bool storageCommitObserved;
  final bool contentIncluded;

  const ForgePromptAppendReceipt({
    required this.conversationID,
    required this.promptID,
    required this.role,
    required this.aggregateVersion,
    required this.createdAtMS,
    required this.replayed,
    required this.storageCommitObserved,
    required this.contentIncluded,
  });

  factory ForgePromptAppendReceipt.fromJson(Object? value) {
    final json = _promptAppendObject(value, 'receipt');
    _promptAppendExactKeys(json, {
      'conversation_id',
      'prompt_id',
      'role',
      'aggregate_version',
      'created_at_ms',
      'replayed',
      'storage_commit_observed',
      'content_included',
    }, 'receipt');
    return ForgePromptAppendReceipt(
      conversationID: _promptAppendIdentifier(
        json['conversation_id'],
        'receipt conversation_id',
      ),
      promptID: _promptAppendIdentifier(json['prompt_id'], 'prompt_id'),
      role: _promptAppendRole(json['role']),
      aggregateVersion: _promptAppendPositiveInt(
        json['aggregate_version'],
        'aggregate_version',
      ),
      createdAtMS: _promptAppendUint(json['created_at_ms'], 'created_at_ms'),
      replayed: _promptAppendBool(json['replayed'], 'replayed'),
      storageCommitObserved: _promptAppendBool(
        json['storage_commit_observed'],
        'storage_commit_observed',
      ),
      contentIncluded: _promptAppendBool(
        json['content_included'],
        'content_included',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'role': role,
    'aggregate_version': aggregateVersion,
    'created_at_ms': createdAtMS,
    'replayed': replayed,
    'storage_commit_observed': storageCommitObserved,
    'content_included': contentIncluded,
  };
}

class ForgePromptAppendReceiptObservation {
  static const schema = forgePromptAppendReceiptSchema;

  final ForgeDeviceOwner owner;
  final ForgePromptAppendReceiptRequest request;
  final ForgePromptAppendReceipt receipt;
  final ForgePromptAppendReceiptAuthority authority;

  const ForgePromptAppendReceiptObservation({
    required this.owner,
    required this.request,
    required this.receipt,
    required this.authority,
  });

  factory ForgePromptAppendReceiptObservation.fromJsonText(String source) {
    if (source.isEmpty ||
        source.length > forgePromptAppendReceiptMaxInputBytes) {
      throw const FormatException('Prompt append receipt input is too large.');
    }
    rejectDuplicateForgeJsonKeys(source);
    return ForgePromptAppendReceiptObservation.fromJson(jsonDecode(source));
  }

  factory ForgePromptAppendReceiptObservation.fromJson(Object? value) {
    final json = _promptAppendObject(value, 'Prompt append receipt');
    _promptAppendExactKeys(json, {
      'schema_version',
      'owner',
      'request',
      'receipt',
      'authority',
    }, 'Prompt append receipt');
    if (json['schema_version'] != schema) {
      throw const FormatException('Prompt append receipt schema is invalid.');
    }
    final observation = ForgePromptAppendReceiptObservation(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      request: ForgePromptAppendReceiptRequest.fromJson(json['request']),
      receipt: ForgePromptAppendReceipt.fromJson(json['receipt']),
      authority: ForgePromptAppendReceiptAuthority.fromJson(json['authority']),
    );
    if (observation.receipt.conversationID !=
            observation.request.conversationID ||
        observation.receipt.role != observation.request.role ||
        observation.receipt.aggregateVersion !=
            observation.request.expectedVersion + 1 ||
        observation.receipt.aggregateVersion >
            forgePromptAppendReceiptMaxSafeInteger ||
        !observation.receipt.storageCommitObserved ||
        observation.receipt.contentIncluded) {
      throw const FormatException('Prompt append receipt binding is invalid.');
    }
    return observation;
  }

  /// Recomputes the content-free envelope from one append's inputs.
  factory ForgePromptAppendReceiptObservation.fromInput({
    required ForgeDeviceOwner owner,
    required String conversationID,
    required int expectedVersion,
    required String content,
    required String idempotencyKey,
    required String promptID,
    required int createdAtMS,
    required bool replayed,
  }) {
    if (content.trim().isEmpty ||
        utf8.encode(content).length > forgePromptAppendReceiptMaxContentBytes) {
      throw ArgumentError.value(content, 'content');
    }
    if (idempotencyKey.trim().isEmpty ||
        utf8.encode(idempotencyKey).length >
            forgePromptAppendReceiptMaxIdempotencyKeyBytes) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    final contentDigest = crypto.sha256
        .convert(utf8.encode(content))
        .toString();
    final idempotencyDigest = crypto.sha256
        .convert(utf8.encode(idempotencyKey))
        .toString();
    return ForgePromptAppendReceiptObservation.fromJson({
      'schema_version': schema,
      'owner': owner.toJson(),
      'request': {
        'conversation_id': conversationID,
        'expected_version': expectedVersion,
        'role': 'user',
        'content_sha256': contentDigest,
        'idempotency_key_sha256': idempotencyDigest,
      },
      'receipt': {
        'conversation_id': conversationID,
        'prompt_id': promptID,
        'role': 'user',
        'aggregate_version': expectedVersion + 1,
        'created_at_ms': createdAtMS,
        'replayed': replayed,
        'storage_commit_observed': true,
        'content_included': false,
      },
      'authority': const {
        'run_created': false,
        'device_selected': false,
        'reservation_created': false,
        'dispatch_performed': false,
        'execution_authorized': false,
        'audit_published': false,
      },
    });
  }

  bool get isDisplayOnly => authority.isClear;

  Map<String, dynamic> toJson() => {
    'schema_version': schema,
    'owner': owner.toJson(),
    'request': request.toJson(),
    'receipt': receipt.toJson(),
    'authority': authority.toJson(),
  };
}
