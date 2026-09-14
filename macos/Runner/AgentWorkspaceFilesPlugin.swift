import Cocoa
import CoreFoundation
import FlutterMacOS
import Foundation

final class AgentWorkspaceFilesPlugin: NSObject, FlutterPlugin {
  private static let channelName = "site.ywbsd.sso/agent_workspace_files"
  private static let maxFileBytes = 524_288
  private static let byteType = FlutterStandardTypedData(bytes: Data()).type
  private static let safeFilenamePrefix = "workspace-"
  private static let safeFilenameSuffix = ".json"

  private enum Operation {
    case pick(maxBytes: Int)
    case save
  }

  private struct PendingOperation {
    let token: UUID
    let operation: Operation
    let result: FlutterResult
    let access = WorkspaceFileAccess()
  }

  private weak var hostViewController: NSViewController?
  private var closed = false
  private var pending: PendingOperation?
  private var panel: NSSavePanel?
  private var windowCloseObserver: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AgentWorkspaceFilesPlugin(viewController: registrar.viewController)
    registrar.publish(instance)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(viewController: NSViewController?) {
    hostViewController = viewController
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !closed else {
      fail("unavailable", result: result)
      return
    }
    switch call.method {
    case "capabilities":
      result(["version": 1, "pick": true, "save": true])
    case "pickJson":
      guard pending == nil else {
        fail("busy", result: result)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            arguments.count == 1,
            let maxBytes = Self.boundedMaxBytes(arguments["maxBytes"]) else {
        fail("invalid_arguments", result: result)
        return
      }
      beginPick(maxBytes: maxBytes, result: result)
    case "saveJson":
      guard pending == nil else {
        fail("busy", result: result)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            arguments.count == 2,
            let filename = arguments["filename"] as? String,
            Self.isSafeFilename(filename),
            let typedData = arguments["bytes"] as? FlutterStandardTypedData,
            typedData.type == Self.byteType else {
        fail("invalid_arguments", result: result)
        return
      }
      guard typedData.data.count <= Self.maxFileBytes else {
        fail("too_large", result: result)
        return
      }
      beginSave(data: typedData.data, filename: filename, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func isSafeFilename(_ filename: String) -> Bool {
    guard filename.hasPrefix(safeFilenamePrefix),
          filename.hasSuffix(safeFilenameSuffix) else {
      return false
    }
    let name = filename.dropFirst(safeFilenamePrefix.count)
      .dropLast(safeFilenameSuffix.count)
    guard (1...96).contains(name.utf8.count) else {
      return false
    }
    return name.utf8.allSatisfy { byte in
      (48...57).contains(byte) || (65...90).contains(byte)
        || (97...122).contains(byte) || byte == 45 || byte == 95
    }
  }

  static func boundedMaxBytes(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
          CFGetTypeID(number) != CFBooleanGetTypeID() else {
      return nil
    }
    let numberType = String(cString: number.objCType)
    guard !["f", "d"].contains(numberType),
          number.int64Value >= 1,
          number.int64Value <= Int64(maxFileBytes) else {
      return nil
    }
    return Int(number.int64Value)
  }

  private func beginPick(maxBytes: Int, result: @escaping FlutterResult) {
    guard let window = activeWindow() else {
      fail("unavailable", result: result)
      return
    }
    let openPanel = NSOpenPanel()
    openPanel.title = "Open workspace JSON"
    openPanel.message = "Choose a JSON workspace file."
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedFileTypes = ["json"]
    let token = UUID()
    pending = PendingOperation(token: token, operation: .pick(maxBytes: maxBytes), result: result)
    panel = openPanel
    observeWindowClose(window, token: token)
    openPanel.beginSheetModal(for: window) { [weak self] response in
      guard let self, self.isCurrent(token, panel: openPanel) else { return }
      guard response == .OK, let url = openPanel.url else {
        self.finish(token: token, value: nil)
        return
      }
      guard url.pathExtension.lowercased() == "json" else {
        self.finish(token: token, error: "invalid_arguments")
        return
      }
      guard let pending = self.pending else { return }
      self.panel = nil // Consume this panel callback before starting asynchronous I/O.
      self.readPickedFile(url, maxBytes: maxBytes, token: token, access: pending.access)
    }
  }

  private func beginSave(data: Data, filename: String,
                         result: @escaping FlutterResult) {
    guard let window = activeWindow() else {
      fail("unavailable", result: result)
      return
    }
    let savePanel = NSSavePanel()
    savePanel.title = "Save workspace JSON"
    savePanel.message = "Choose where to save the workspace file."
    savePanel.prompt = "Save"
    savePanel.nameFieldStringValue = filename
    savePanel.isExtensionHidden = false
    savePanel.canCreateDirectories = true
    savePanel.allowedFileTypes = ["json"]
    let token = UUID()
    pending = PendingOperation(token: token, operation: .save, result: result)
    panel = savePanel
    observeWindowClose(window, token: token)
    savePanel.beginSheetModal(for: window) { [weak self] response in
      guard let self, self.isCurrent(token, panel: savePanel) else { return }
      guard response == .OK, let url = savePanel.url else {
        self.finish(token: token, value: false)
        return
      }
      guard let pending = self.pending else { return }
      self.panel = nil
      self.writeSelectedFile(data, to: url, token: token, access: pending.access)
    }
  }

  private func activeWindow() -> NSWindow? {
    if let window = hostViewController?.view.window {
      return window
    }
    return NSApp.keyWindow ?? NSApp.mainWindow
  }

  private func readPickedFile(_ url: URL, maxBytes: Int, token: UUID,
                              access: WorkspaceFileAccess) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let accessGranted = url.startAccessingSecurityScopedResource()
      defer {
        if accessGranted {
          url.stopAccessingSecurityScopedResource()
        }
      }
      do {
        let data = try access.read(url, maxBytes: maxBytes)
        DispatchQueue.main.async {
          self?.finish(token: token, value: FlutterStandardTypedData(bytes: data))
        }
      } catch WorkspaceFileFailure.tooLarge {
        DispatchQueue.main.async { self?.finish(token: token, error: "too_large") }
      } catch {
        DispatchQueue.main.async { self?.finish(token: token, error: "io_error") }
      }
    }
  }

  private func writeSelectedFile(_ data: Data, to url: URL, token: UUID,
                                 access: WorkspaceFileAccess) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let accessGranted = url.startAccessingSecurityScopedResource()
      defer {
        if accessGranted {
          url.stopAccessingSecurityScopedResource()
        }
      }
      do {
        try access.write(data, to: url)
        DispatchQueue.main.async { self?.finish(token: token, value: true) }
      } catch {
        DispatchQueue.main.async { self?.finish(token: token, error: "io_error") }
      }
    }
  }

  private func finish(token: UUID, value: Any?) {
    guard let current = pending, current.token == token else { return }
    let callback = current.result
    pending = nil
    panel = nil
    stopObservingWindow()
    current.access.cancel()
    callback(value)
  }

  private func finish(token: UUID, error code: String) {
    guard let current = pending, current.token == token else { return }
    let callback = current.result
    pending = nil
    panel = nil
    stopObservingWindow()
    current.access.cancel()
    callback(Self.flutterError(code))
  }

  private func isCurrent(_ token: UUID, panel candidate: NSSavePanel) -> Bool {
    pending?.token == token && panel === candidate
  }

  private func observeWindowClose(_ window: NSWindow, token: UUID) {
    stopObservingWindow()
    windowCloseObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: window,
      queue: .main
    ) { [weak self] _ in
      guard let self, self.pending?.token == token else { return }
      self.close()
    }
  }

  private func stopObservingWindow() {
    if let windowCloseObserver {
      NotificationCenter.default.removeObserver(windowCloseObserver)
    }
    windowCloseObserver = nil
  }

  func close() {
    guard !closed else { return }
    closed = true
    let activePanel = panel
    if let token = pending?.token {
      finish(token: token, error: "unavailable")
    }
    panel = nil
    stopObservingWindow()
    activePanel?.cancel(nil)
  }

  // macOS FlutterPlugin has no detach callback. The engine owns the published plugin;
  // releasing it cancels the request, while window closure calls close() above.
  deinit {
    pending?.access.cancel()
    if let observer = windowCloseObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    let activePanel = panel
    let callback = pending?.result
    DispatchQueue.main.async {
      activePanel?.cancel(nil)
      callback?(Self.flutterError("unavailable"))
    }
  }

  private func fail(_ code: String, result: @escaping FlutterResult) {
    result(Self.flutterError(code))
  }

  private static func flutterError(_ code: String) -> FlutterError {
    let message: String
    switch code {
    case "invalid_arguments": message = "Invalid file request."
    case "too_large": message = "File exceeds the allowed size."
    case "busy": message = "A file operation is already in progress."
    case "io_error": message = "Unable to read or write the file."
    default: message = "File access is unavailable."
    }
    return FlutterError(code: code, message: message, details: nil)
  }
}
