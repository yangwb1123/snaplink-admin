import Darwin
import Foundation
import XCTest
import Cocoa
import FlutterMacOS
@testable import sso_admin

class RunnerTests: XCTestCase {
  func testWorkspaceFilenameIsAnExactSafeJsonBasename() {
    for name in ["workspace-a.json", "workspace-task_2-A.json",
                 "workspace-\(String(repeating: "a", count: 96)).json"] {
      XCTAssertTrue(AgentWorkspaceFilesPlugin.isSafeFilename(name), name)
    }
    for name in ["../workspace-task.json", "workspace-task.json\n", "workspace-é.json",
                 "workspace-.json", "workspace-a/b.json", "workspace-a\\b.json",
                 "workspace-\(String(repeating: "a", count: 97)).json"] {
      XCTAssertFalse(AgentWorkspaceFilesPlugin.isSafeFilename(name), name)
    }
  }

  func testWorkspacePickLimitRejectsBooleanFloatingAndOutOfRangeValues() {
    for value in [1, 524_288] {
      XCTAssertEqual(AgentWorkspaceFilesPlugin.boundedMaxBytes(NSNumber(value: value)), value)
    }
    let invalid: [Any] = [true, false, NSNumber(value: 1.0), NSNumber(value: 524_288.0),
                          0, -1, 524_289, "1", NSNull(), NSNumber(value: UInt64.max)]
    for value in invalid {
      XCTAssertNil(AgentWorkspaceFilesPlugin.boundedMaxBytes(value))
    }
  }

  func testPickRejectsExtraMissingOrMistypedArguments() {
    let plugin = AgentWorkspaceFilesPlugin(viewController: nil)
    let invalid: [Any] = [NSNull(), [:], ["maxBytes": true], ["maxBytes": 1.0],
                          ["maxBytes": 1, "path": "/private/file.json"], ["path": 1]]
    for arguments in invalid {
      assertError(plugin, method: "pickJson", arguments: arguments, code: "invalid_arguments")
    }
  }

  func testSaveRejectsWrongTypedArraysAndUnsafeFilenameWithoutOpeningDialog() {
    let plugin = AgentWorkspaceFilesPlugin(viewController: nil)
    let invalidBytes: [Any] = [Data([1]), [1, 2], NSNull(),
                               FlutterStandardTypedData(int32: Data(repeating: 0, count: 4)),
                               FlutterStandardTypedData(float64: Data(repeating: 0, count: 8))]
    for bytes in invalidBytes {
      assertError(plugin, method: "saveJson", arguments: ["filename": "workspace-a.json",
                                                           "bytes": bytes],
                  code: "invalid_arguments")
    }
    assertError(plugin, method: "saveJson", arguments: ["filename": "workspace-a.json\n",
                 "bytes": FlutterStandardTypedData(bytes: Data())], code: "invalid_arguments")
    assertError(plugin, method: "saveJson", arguments: ["filename": "workspace-a.json",
                 "bytes": FlutterStandardTypedData(bytes: Data()), "path": "/private/file"],
                code: "invalid_arguments")
  }

  func testSaveRejectsOversizeBytesBeforeShowingDialog() {
    assertError(AgentWorkspaceFilesPlugin(viewController: nil), method: "saveJson",
                arguments: ["filename": "workspace-a.json",
                  "bytes": FlutterStandardTypedData(bytes: Data(repeating: 65, count: 524_289))],
                code: "too_large")
  }

  func testClosedPluginNeverAdvertisesOrStartsNewOperations() {
    let plugin = AgentWorkspaceFilesPlugin(viewController: nil)
    plugin.close()
    plugin.close()
    for method in ["capabilities", "pickJson", "saveJson"] {
      assertError(plugin, method: method, arguments: nil, code: "unavailable")
    }
  }

  func testBoundedCollectorPreservesShortReadsThroughEOF() throws {
    var chunks = [Data([1]), Data([2, 3]), Data([4]), Data()]
    var requested: [Int] = []
    let result = try WorkspaceFileAccess.collectBounded(maxBytes: 4) { limit in
      requested.append(limit)
      return chunks.removeFirst()
    }
    XCTAssertEqual(result, Data([1, 2, 3, 4]))
    XCTAssertEqual(requested, [5, 4, 2, 1])
  }

  func testBoundedCollectorAcceptsEmptyAndExactMaximum() throws {
    XCTAssertEqual(try WorkspaceFileAccess.collectBounded(maxBytes: 1) { _ in nil }, Data())
    var remaining = 524_288
    let data = try WorkspaceFileAccess.collectBounded(maxBytes: 524_288) { requested in
      let count = min(requested, remaining)
      remaining -= count
      return Data(repeating: 65, count: count)
    }
    XCTAssertEqual(data.count, 524_288)
  }

  func testBoundedCollectorStopsAtFirstBytePastLimit() {
    var consumed = 0
    XCTAssertThrowsError(try WorkspaceFileAccess.collectBounded(maxBytes: 3) { _ in
      consumed += 1
      return Data([65])
    })
    XCTAssertEqual(consumed, 4)
  }

  func testBoundedCollectorPropagatesReadFailures() {
    var calls = 0
    XCTAssertThrowsError(try WorkspaceFileAccess.collectBounded(maxBytes: 3) { _ in
      calls += 1
      if calls == 1 { return Data([65]) }
      throw CocoaError(.fileReadUnknown)
    })
    XCTAssertEqual(calls, 2)
  }

  func testReadRegularFilePreservesBytesAndEnforcesLimit() throws {
    try withTemporaryDirectory { directory in
      let file = directory.appendingPathComponent("input.json")
      let bytes = Data([0, 10, 65, 128, 255])
      try bytes.write(to: file)
      XCTAssertEqual(try WorkspaceFileAccess.readBounded(file, maxBytes: 5), bytes)
      XCTAssertThrowsError(try WorkspaceFileAccess.readBounded(file, maxBytes: 4))
      XCTAssertThrowsError(try WorkspaceFileAccess.readBounded(directory, maxBytes: 5))
    }
  }

  func testReadRejectsFifoWithoutWaitingForAWriter() throws {
    try withTemporaryDirectory { directory in
      let fifo = directory.appendingPathComponent("pipe.json")
      let status = fifo.path.withCString { mkfifo($0, 0o600) }
      XCTAssertEqual(status, 0)
      XCTAssertThrowsError(try WorkspaceFileAccess.readBounded(fifo, maxBytes: 32))
    }
  }

  func testCancelledAccessDoesNotReadOrWrite() throws {
    try withTemporaryDirectory { directory in
      let file = directory.appendingPathComponent("input.json")
      let original = Data([65])
      try original.write(to: file)
      let access = WorkspaceFileAccess()
      access.cancel()
      access.cancel()
      XCTAssertThrowsError(try access.read(file, maxBytes: 5))
      XCTAssertThrowsError(try access.write(Data([66]), to: file))
      XCTAssertEqual(try Data(contentsOf: file), original)
    }
  }

  func testCoordinatedSaveReplacesLongerFileAndAllowsRenamedDestination() throws {
    try withTemporaryDirectory { directory in
      let file = directory.appendingPathComponent("user chosen name.json")
      try Data(repeating: 65, count: 100).write(to: file)
      let bytes = Data([123, 125])
      try WorkspaceFileAccess().write(bytes, to: file)
      XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
  }

  private func assertError(_ plugin: AgentWorkspaceFilesPlugin, method: String,
                           arguments: Any?, code: String,
                           file: StaticString = #filePath, line: UInt = #line) {
    var callbacks = 0
    plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { value in
      callbacks += 1
      guard let error = value as? FlutterError else {
        XCTFail("Expected a fixed channel error", file: file, line: line)
        return
      }
      XCTAssertEqual(error.code, code, file: file, line: line)
      XCTAssertNil(error.details, file: file, line: line)
      XCTAssertFalse(error.message?.contains("/private/") ?? false, file: file, line: line)
    }
    XCTAssertEqual(callbacks, 1, file: file, line: line)
  }

  private func withTemporaryDirectory(_ action: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("workspace-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    try action(directory)
  }
}
