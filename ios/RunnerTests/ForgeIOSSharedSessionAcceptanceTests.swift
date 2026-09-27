import Foundation
import XCTest

private enum ForgeIOSSharedSessionAcceptancePolicy {
  static let optInEnvironmentKey = "FORGE_IOS_SHARED_SESSION_ACCEPTANCE"

  static func isOptedIn(_ environment: [String: String]) -> Bool {
    environment[optInEnvironmentKey] == "1"
  }

  static func permits(method: String, path: String,
                      conversationID: String) -> Bool {
    guard method == "GET" || method == "POST" else { return false }
    if method == "GET" && path == "/api/v1/conversations" { return true }
    if method == "GET" && path == "/api/v1/conversation-changes" { return true }
    if method == "GET" && path == "/api/v1/client-instances/session-view" { return true }
    if method == "GET" && path == "/api/v1/client-instances/resource-view" { return true }
    let promptPath = "/api/v1/conversations/\(conversationID)/prompts"
    return path == promptPath
  }
}

private struct ForgeIOSSharedSessionInput: Decodable {
  let platform: String
  let apiURL: String
  let accessToken: String
  let rotatedAccessToken: String
  let conversationID: String
  let clientInstanceID: String
  let expectedVersion: Int
  let afterCursor: Int
  let prompt: String
  let idempotencyKey: String

  private enum CodingKeys: String, CodingKey {
    case platform
    case apiURL = "api_url"
    case accessToken = "access_token"
    case rotatedAccessToken = "rotated_access_token"
    case conversationID = "conversation_id"
    case clientInstanceID = "client_instance_id"
    case expectedVersion = "expected_version"
    case afterCursor = "after_cursor"
    case prompt
    case idempotencyKey = "idempotency_key"
  }

  private static let expectedKeys: Set<String> = [
    "platform", "api_url", "access_token", "rotated_access_token",
    "conversation_id", "client_instance_id", "session_view",
    "resource_view", "expected_version", "after_cursor", "prompt",
    "idempotency_key",
  ]

  static func read(from url: URL) throws -> Self {
    let resourceValues = try url.resourceValues(
      forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
    )
    guard resourceValues.isRegularFile == true,
          resourceValues.isSymbolicLink != true else {
      throw ValidationError.invalidFile
    }
    let values = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let type = values[.type] as? FileAttributeType,
          type == .typeRegular else {
      throw ValidationError.invalidFile
    }
    guard (values[.posixPermissions] as? NSNumber).map({ $0.intValue & 0o077 == 0 }) == true else {
      throw ValidationError.insecurePermissions
    }
    let data = try Data(contentsOf: url)
    guard data.count <= 64 * 1024 else { throw ValidationError.tooLarge }
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          Set(object.keys) == expectedKeys else {
      throw ValidationError.schema
    }
    guard let sessionView = object["session_view"] as? [String: Any],
          let resourceView = object["resource_view"] as? [String: Any] else {
      throw ValidationError.convergence
    }
    let input = try JSONDecoder().decode(Self.self, from: data)
    try validateSessionResourcePair(
      sessionView: sessionView,
      resourceView: resourceView,
      conversationID: input.conversationID,
      clientInstanceID: input.clientInstanceID
    )
    try input.validate()
    return input
  }

  private func validate() throws {
    guard platform == "ios-device" || platform == "ios-simulator" else {
      throw ValidationError.platform
    }
    guard let components = URLComponents(string: apiURL),
          let scheme = components.scheme?.lowercased(),
          let host = components.host?.lowercased(),
          components.user == nil,
          components.password == nil,
          components.query == nil,
          components.fragment == nil,
          components.path.isEmpty || components.path == "/" else {
      throw ValidationError.apiURL
    }
    guard components.port == nil || (components.port ?? 0) >= 1 && (components.port ?? 0) <= 65_535,
          !host.isEmpty else {
      throw ValidationError.apiURL
    }
    if scheme == "http" {
      guard host == "localhost" || host == "127.0.0.1" || host == "::1" else {
        throw ValidationError.apiURL
      }
    } else if scheme != "https" {
      throw ValidationError.apiURL
    }
    try Self.requireString(accessToken, maximum: 16 * 1024)
    try Self.requireString(rotatedAccessToken, maximum: 16 * 1024)
    guard accessToken != rotatedAccessToken else { throw ValidationError.tokenRotation }
    try Self.requireIdentifier(conversationID)
    try Self.requireIdentifier(clientInstanceID)
    try Self.requireString(prompt, maximum: 32 * 1024)
    try Self.requireIdentifier(idempotencyKey)
    guard expectedVersion >= 1, expectedVersion <= 9_007_199_254_740_991,
          afterCursor >= 0, afterCursor <= 9_007_199_254_740_991 else {
      throw ValidationError.counter
    }
  }

  private static func requireString(_ value: String, maximum: Int) throws {
    guard !value.isEmpty, value.utf8.count <= maximum,
          !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F })
    else { throw ValidationError.string }
  }

  private static func validateSessionResourcePair(
    sessionView: [String: Any], resourceView: [String: Any],
    conversationID: String, clientInstanceID: String
  ) throws {
    let session = try validateView(sessionView, resource: false)
    let resource = try validateView(resourceView, resource: true)
    guard session.owner == resource.owner else { throw ValidationError.convergence }
    let sessionInstances = try canonicalJSON(session.instances)
    let resourceInstances = try canonicalJSON(resource.instances)
    guard sessionInstances == resourceInstances else {
      throw ValidationError.convergence
    }
    guard let selected = session.instances.first(where: {
      ($0["instance_id"] as? String) == clientInstanceID
    }), (selected["client_kind"] as? String) == "mobile" else {
      throw ValidationError.convergence
    }
    guard let sessionIDs = selected["session_ids"] as? [Any],
          sessionIDs.contains(where: { ($0 as? String) == conversationID }) else {
      throw ValidationError.convergence
    }
  }

  private static func validateView(
    _ view: [String: Any], resource: Bool
  ) throws -> (owner: [String: String], instances: [[String: Any]]) {
    let sessionKeys: Set<String> = [
      "schema_version", "evaluation_mode", "owner_declaration",
      "owner_declaration_unverified", "instances", "read_only", "authority",
    ]
    let resourceKeys = sessionKeys.union(["devices", "device_attributes_unverified"])
    guard Set(view.keys) == (resource ? resourceKeys : sessionKeys),
          (view["schema_version"] as? String) == (resource
            ? "forge.client-instance-resource-view/v1"
            : "forge.client-instance-session-view/v1"),
          (view["evaluation_mode"] as? String) == (resource
            ? "owner_bound_instance_resource_view_only"
            : "owner_bound_session_view_only"),
          (view["owner_declaration_unverified"] as? Bool) == true,
          (view["read_only"] as? Bool) == true else {
      throw ValidationError.convergence
    }
    try validateAuthority(view["authority"])
    let owner = try validateOwner(view["owner_declaration"])
    guard let rawInstances = view["instances"] as? [Any], rawInstances.count <= 128 else {
      throw ValidationError.convergence
    }
    var instances = [[String: Any]]()
    for raw in rawInstances {
      guard let instance = raw as? [String: Any] else { throw ValidationError.convergence }
      try validateInstance(instance)
      instances.append(instance)
    }
    let instanceIDs = instances.compactMap { $0["instance_id"] as? String }
    guard instanceIDs.count == instances.count,
          instanceIDs == Array(Set(instanceIDs)).sorted() else {
      throw ValidationError.convergence
    }
    if resource {
      guard (view["device_attributes_unverified"] as? Bool) == true,
            let devices = view["devices"] as? [Any], devices.count <= 128 else {
        throw ValidationError.convergence
      }
      try validateDevices(devices, owner: owner)
    }
    return (owner, instances)
  }

  private static func validateOwner(_ value: Any?) throws -> [String: String] {
    guard let owner = value as? [String: Any], Set(owner.keys) == Set([
      "issuer", "subject", "tenant_id",
    ]) else { throw ValidationError.convergence }
    var result = [String: String]()
    for key in ["issuer", "subject", "tenant_id"] {
      guard let text = owner[key] as? String else { throw ValidationError.convergence }
      try requireString(text, maximum: 512)
      result[key] = text
    }
    return result
  }

  private static func validateAuthority(_ value: Any?) throws {
    let keys: Set<String> = [
      "owner_authenticated", "session_read_authorized", "prompt_write_authorized",
      "device_identity_verified", "reservation_created", "execution_authorized",
      "dispatch_performed", "audit_published",
    ]
    guard let authority = value as? [String: Any], Set(authority.keys) == keys,
          authority.values.allSatisfy({ ($0 as? Bool) == false }) else {
      throw ValidationError.convergence
    }
  }

  private static func validateInstance(_ instance: [String: Any]) throws {
    let keys: Set<String> = [
      "instance_id", "client_kind", "session_ids", "observed_at_ms", "status",
    ]
    guard Set(instance.keys) == keys,
          let instanceID = instance["instance_id"] as? String,
          let clientKind = instance["client_kind"] as? String,
          ["cli", "tui", "web", "app", "mobile"].contains(clientKind),
          let sessionIDs = instance["session_ids"] as? [Any], sessionIDs.count <= 128,
          let observedAt = integer(instance["observed_at_ms"]), observedAt > 0,
          let status = instance["status"] as? String,
          ["active", "idle", "offline", "unknown"].contains(status) else {
      throw ValidationError.convergence
    }
    try requireIdentifier(instanceID)
    var normalized = [String]()
    for raw in sessionIDs {
      guard let sessionID = raw as? String else { throw ValidationError.convergence }
      try requireIdentifier(sessionID)
      normalized.append(sessionID)
    }
    guard normalized == Array(Set(normalized)).sorted() else {
      throw ValidationError.convergence
    }
  }

  private static func validateDevices(
    _ devices: [Any], owner: [String: String]
  ) throws {
    let keys: Set<String> = [
      "device_id", "runner_instance_id", "owner", "revision", "generation",
      "heartbeat_sequence", "observed_at_ms", "approval_state", "cordon_state",
      "reservation_state", "liveness", "os", "architecture", "cpu_cores",
      "available_cpu_cores", "memory_bytes", "available_memory_bytes",
      "storage_bytes", "available_storage_bytes", "gpu_count",
      "available_gpu_memory_bytes",
    ]
    var order = [(String, String)]()
    for raw in devices {
      guard let device = raw as? [String: Any], Set(device.keys) == keys,
            let deviceID = device["device_id"] as? String,
            let runnerID = device["runner_instance_id"] as? String,
            tryOwner(device["owner"], equals: owner),
            ["approved", "pending", "revoked", "unknown"].contains(device["approval_state"] as? String),
            ["clear", "cordoned", "unknown"].contains(device["cordon_state"] as? String),
            ["none", "reserved", "unknown"].contains(device["reservation_state"] as? String),
            ["online", "offline", "unknown"].contains(device["liveness"] as? String) else {
        throw ValidationError.convergence
      }
      try requireIdentifier(deviceID)
      try requireIdentifier(runnerID)
      for key in ["revision", "generation", "heartbeat_sequence", "observed_at_ms"] {
        guard let value = integer(device[key]), value > 0 else { throw ValidationError.convergence }
      }
      for key in [
        "cpu_cores", "available_cpu_cores", "memory_bytes", "available_memory_bytes",
        "storage_bytes", "available_storage_bytes", "gpu_count", "available_gpu_memory_bytes",
      ] {
        guard integer(device[key]) != nil else { throw ValidationError.convergence }
      }
      guard let cpu = integer(device["cpu_cores"]),
            let availableCPU = integer(device["available_cpu_cores"]), availableCPU <= cpu,
            let memory = integer(device["memory_bytes"]),
            let availableMemory = integer(device["available_memory_bytes"]), availableMemory <= memory,
            let storage = integer(device["storage_bytes"]),
            let availableStorage = integer(device["available_storage_bytes"]), availableStorage <= storage,
            let os = device["os"] as? String, let architecture = device["architecture"] as? String else {
        throw ValidationError.convergence
      }
      try requireString(os, maximum: 128)
      try requireString(architecture, maximum: 128)
      order.append((deviceID, runnerID))
    }
    let uniqueOrder = Set(order.map { "\($0.0)\u{0}\($0.1)" })
    guard uniqueOrder.count == order.count,
          order == order.sorted(by: {
            $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0
          }) else { throw ValidationError.convergence }
  }

  private static func tryOwner(
    _ value: Any?, equals expected: [String: String]
  ) -> Bool {
    guard let owner = try? validateOwner(value) else { return false }
    return owner == expected
  }

  private static func integer(_ value: Any?) -> Int64? {
    guard value as? Bool == nil, let number = value as? NSNumber else { return nil }
    let integer = number.int64Value
    guard number.doubleValue == Double(integer), integer >= 0,
          integer <= 9_007_199_254_740_991 else { return nil }
    return integer
  }

  private static func canonicalJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
  }

  private static func requireIdentifier(_ value: String) throws {
    try requireString(value, maximum: 512)
    guard value.unicodeScalars.allSatisfy({ scalar in
      switch scalar.value {
      case 48...57, 65...90, 97...122, 45, 46, 58, 95:
        return true
      default:
        return false
      }
    }) else {
      throw ValidationError.identifier
    }
  }

  enum ValidationError: Error {
    case invalidFile
    case insecurePermissions
    case tooLarge
    case schema
    case platform
    case apiURL
    case tokenRotation
    case counter
    case string
    case identifier
    case convergence
  }
}

final class ForgeIOSSharedSessionAcceptanceTests: XCTestCase {
  func testOptInIsExplicitAndDefaultsClosed() {
    XCTAssertFalse(ForgeIOSSharedSessionAcceptancePolicy.isOptedIn([:]))
    XCTAssertFalse(ForgeIOSSharedSessionAcceptancePolicy.isOptedIn([
      ForgeIOSSharedSessionAcceptancePolicy.optInEnvironmentKey: "0",
    ]))
    XCTAssertFalse(ForgeIOSSharedSessionAcceptancePolicy.isOptedIn([
      ForgeIOSSharedSessionAcceptancePolicy.optInEnvironmentKey: "true",
    ]))
    XCTAssertTrue(ForgeIOSSharedSessionAcceptancePolicy.isOptedIn([
      ForgeIOSSharedSessionAcceptancePolicy.optInEnvironmentKey: "1",
    ]))
  }

  func testExplicitRunnerInputUsesThePrivateFileBoundary() throws {
    let environment = ProcessInfo.processInfo.environment
    guard ForgeIOSSharedSessionAcceptancePolicy.isOptedIn(environment) else {
      throw XCTSkip("the native acceptance runner is opt-in")
    }
    guard let path = environment["FORGE_IOS_SHARED_SESSION_INPUT"], !path.isEmpty else {
      XCTFail("opt-in runner did not provide a private input path")
      return
    }
    let input = try ForgeIOSSharedSessionInput.read(from: URL(fileURLWithPath: path))
    XCTAssertTrue(input.platform == "ios-device" || input.platform == "ios-simulator")
    XCTAssertTrue(
      ForgeIOSSharedSessionAcceptancePolicy.permits(
        method: "POST",
        path: "/api/v1/conversations/\(input.conversationID)/prompts",
        conversationID: input.conversationID
      )
    )
  }

  func testPrivateInputSchemaAcceptsRotatedCredentialFixture() throws {
    let url = try writeFixture([
      "platform": "ios-simulator",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "continue the owner conversation",
      "idempotency_key": "ios-acceptance-prompt-1",
    ])
    let input = try ForgeIOSSharedSessionInput.read(from: url)
    XCTAssertEqual(input.platform, "ios-simulator")
    XCTAssertEqual(input.expectedVersion, 7)
    XCTAssertEqual(input.afterCursor, 19)
    XCTAssertEqual(input.conversationID, "conversation-42")
    XCTAssertEqual(input.clientInstanceID, "client-mobile-001")
    XCTAssertNotEqual(input.accessToken, input.rotatedAccessToken)
  }

  func testPrivateInputRejectsExtraFieldsUnsafeOriginAndUnrotatedToken() throws {
    let extra = try writeFixture([
      "platform": "ios-simulator",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
      "unexpected": true,
    ])
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: extra))

    let publicHTTP = try writeFixture([
      "platform": "ios-device",
      "api_url": "http://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
    ])
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: publicHTTP))

    let sameToken = try writeFixture([
      "platform": "ios-device",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-a",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
    ])
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: sameToken))

    let unsafeIdentifier = try writeFixture([
      "platform": "ios-device",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation/42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
    ])
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: unsafeIdentifier))
  }

  func testPrivateInputRejectsSymbolicLink() throws {
    let target = try writeFixture([
      "platform": "ios-device",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
    ])
    let link = target.deletingLastPathComponent().appendingPathComponent("link.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: link))
  }

  func testOnlyConversationPromptAndChangeFeedRoutesArePermitted() {
    let conversationID = "conversation-42"
    let allowed = [
      ("GET", "/api/v1/conversations"),
      ("GET", "/api/v1/conversation-changes"),
      ("GET", "/api/v1/conversations/conversation-42/prompts"),
      ("POST", "/api/v1/conversations/conversation-42/prompts"),
      ("GET", "/api/v1/client-instances/session-view"),
      ("GET", "/api/v1/client-instances/resource-view"),
    ]
    for (method, path) in allowed {
      XCTAssertTrue(
        ForgeIOSSharedSessionAcceptancePolicy.permits(
          method: method, path: path, conversationID: conversationID
        ),
        "unexpectedly blocked \(method) \(path)"
      )
    }

    let forbidden = [
      "/api/v1/devices",
      "/api/v1/device-inventory",
      "/api/v1/placement",
      "/api/v1/reservations",
      "/api/v1/dispatch",
      "/api/v1/run-intents",
      "/api/v1/execution",
      "/api/v1/receipts",
      "/api/v1/conversations/conversation-42/prompts?device_id=runner-1",
      "/api/v1/client-instances/session-view?instance_id=client-mobile-001",
      "/api/v1/client-instances/resource-view",
    ]
    for path in forbidden {
      XCTAssertFalse(
        ForgeIOSSharedSessionAcceptancePolicy.permits(
          method: "POST",
          path: path, conversationID: conversationID
        ),
        "forbidden route was permitted: \(path)"
      )
    }
  }

  func testPrivateInputRejectsHiddenMissingOwnerAndInstanceDrift() throws {
    var hidden = baseFixture()
    var hiddenSession = hidden["session_view"] as! [String: Any]
    var hiddenInstances = hiddenSession["instances"] as! [[String: Any]]
    hiddenInstances[0]["session_ids"] = [String]()
    hiddenSession["instances"] = hiddenInstances
    hidden["session_view"] = hiddenSession
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: try writeFixture(hidden)))

    var missing = baseFixture()
    var missingResource = missing["resource_view"] as! [String: Any]
    var missingInstances = missingResource["instances"] as! [[String: Any]]
    missingInstances.removeAll { ($0["instance_id"] as? String) == "client-mobile-001" }
    missingResource["instances"] = missingInstances
    missing["resource_view"] = missingResource
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: try writeFixture(missing)))

    var ownerDrift = baseFixture()
    var driftedOwnerResource = ownerDrift["resource_view"] as! [String: Any]
    var driftedOwner = driftedOwnerResource["owner_declaration"] as! [String: Any]
    driftedOwner["subject"] = "other-user"
    driftedOwnerResource["owner_declaration"] = driftedOwner
    ownerDrift["resource_view"] = driftedOwnerResource
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: try writeFixture(ownerDrift)))

    var instanceDrift = baseFixture()
    var driftedResource = instanceDrift["resource_view"] as! [String: Any]
    var driftedInstances = driftedResource["instances"] as! [[String: Any]]
    driftedInstances[0]["observed_at_ms"] = 200501
    driftedResource["instances"] = driftedInstances
    instanceDrift["resource_view"] = driftedResource
    XCTAssertThrowsError(try ForgeIOSSharedSessionInput.read(from: try writeFixture(instanceDrift)))
  }

  private func writeFixture(_ object: [String: Any]) throws -> URL {
    var enriched = object
    if enriched["client_instance_id"] == nil {
      enriched["client_instance_id"] = "client-mobile-001"
    }
    if enriched["session_view"] == nil || enriched["resource_view"] == nil {
      for (key, value) in convergenceFixture() where enriched[key] == nil {
        enriched[key] = value
      }
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("forge-ios-acceptance-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700]
    )
    let file = directory.appendingPathComponent("input.json")
    let data = try JSONSerialization.data(withJSONObject: enriched, options: [])
    FileManager.default.createFile(atPath: file.path, contents: data,
                                   attributes: [.posixPermissions: 0o600])
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return file
  }

  private func baseFixture() -> [String: Any] {
    var value: [String: Any] = [
      "platform": "ios-simulator",
      "api_url": "https://coordinator.example.test",
      "access_token": "access-token-a",
      "rotated_access_token": "access-token-b",
      "conversation_id": "conversation-42",
      "expected_version": 7,
      "after_cursor": 19,
      "prompt": "prompt",
      "idempotency_key": "key",
    ]
    for (key, item) in convergenceFixture() { value[key] = item }
    return value
  }

  private func convergenceFixture() -> [String: Any] {
    let owner: [String: Any] = [
      "issuer": "https://id.example",
      "subject": "user-1",
      "tenant_id": "tenant-1",
    ]
    let authority: [String: Any] = [
      "owner_authenticated": false,
      "session_read_authorized": false,
      "prompt_write_authorized": false,
      "device_identity_verified": false,
      "reservation_created": false,
      "execution_authorized": false,
      "dispatch_performed": false,
      "audit_published": false,
    ]
    let instance: [String: Any] = [
      "instance_id": "client-mobile-001",
      "client_kind": "mobile",
      "session_ids": ["conversation-42"],
      "observed_at_ms": 200500,
      "status": "active",
    ]
    let session: [String: Any] = [
      "schema_version": "forge.client-instance-session-view/v1",
      "evaluation_mode": "owner_bound_session_view_only",
      "owner_declaration": owner,
      "owner_declaration_unverified": true,
      "instances": [instance],
      "read_only": true,
      "authority": authority,
    ]
    let resource: [String: Any] = [
      "schema_version": "forge.client-instance-resource-view/v1",
      "evaluation_mode": "owner_bound_instance_resource_view_only",
      "owner_declaration": owner,
      "owner_declaration_unverified": true,
      "instances": [instance],
      "devices": [],
      "device_attributes_unverified": true,
      "read_only": true,
      "authority": authority,
    ]
    return ["client_instance_id": "client-mobile-001", "session_view": session, "resource_view": resource]
  }
}
