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
    case expectedVersion = "expected_version"
    case afterCursor = "after_cursor"
    case prompt
    case idempotencyKey = "idempotency_key"
  }

  private static let expectedKeys: Set<String> = [
    "platform", "api_url", "access_token", "rotated_access_token",
    "conversation_id", "expected_version", "after_cursor", "prompt",
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
    let input = try JSONDecoder().decode(Self.self, from: data)
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
    ]
    for path in forbidden {
      XCTAssertFalse(
        ForgeIOSSharedSessionAcceptancePolicy.permits(
          method: "POST", path: path, conversationID: conversationID
        ),
        "forbidden route was permitted: \(path)"
      )
    }
  }

  private func writeFixture(_ object: [String: Any]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("forge-ios-acceptance-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700]
    )
    let file = directory.appendingPathComponent("input.json")
    let data = try JSONSerialization.data(withJSONObject: object, options: [])
    FileManager.default.createFile(atPath: file.path, contents: data,
                                   attributes: [.posixPermissions: 0o600])
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return file
  }
}
