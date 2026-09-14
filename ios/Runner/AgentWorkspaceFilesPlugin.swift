import CoreFoundation
import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

final class AgentWorkspaceFilesPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate {
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

  private weak var registeredViewController: UIViewController?
  private var closed = false
  private var pending: PendingOperation?
  private var picker: UIDocumentPickerViewController?
  private var exportDirectory: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AgentWorkspaceFilesPlugin(viewController: registrar.viewController)
    registrar.publish(instance)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(viewController: UIViewController?) {
    registeredViewController = viewController
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
    guard let presenter = activePresenter() else {
      fail("unavailable", result: result)
      return
    }
    let documentPicker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      documentPicker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.json], asCopy: false
      )
    } else {
      documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.json"], in: .open
      )
    }
    documentPicker.allowsMultipleSelection = false
    documentPicker.delegate = self
    let token = UUID()
    pending = PendingOperation(token: token, operation: .pick(maxBytes: maxBytes), result: result)
    picker = documentPicker
    presenter.present(documentPicker, animated: true) { [weak self] in
      guard let self, self.isCurrent(token, picker: documentPicker) else { return }
      documentPicker.presentationController?.delegate = self
    }
  }

  private func beginSave(data: Data, filename: String,
                         result: @escaping FlutterResult) {
    guard let presenter = activePresenter() else {
      fail("unavailable", result: result)
      return
    }
    do {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-workspace-\(UUID().uuidString)",
                                isDirectory: true)
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
      )
      exportDirectory = directory
      let file = directory.appendingPathComponent(filename, isDirectory: false)
      try data.write(to: file, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                            ofItemAtPath: file.path)
      let documentPicker = exportPicker(for: file)
      documentPicker.delegate = self
      let token = UUID()
      pending = PendingOperation(token: token, operation: .save, result: result)
      picker = documentPicker
      presenter.present(documentPicker, animated: true) { [weak self] in
        guard let self, self.isCurrent(token, picker: documentPicker) else { return }
        documentPicker.presentationController?.delegate = self
      }
    } catch {
      removeExportDirectory()
      fail("io_error", result: result)
    }
  }

  private func exportPicker(for file: URL) -> UIDocumentPickerViewController {
    if #available(iOS 14.0, *) {
      return UIDocumentPickerViewController(forExporting: [file], asCopy: true)
    }
    return UIDocumentPickerViewController(url: file, in: .exportToService)
  }

  private func activePresenter() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?
      .windows.first { $0.isKeyWindow }
    let root = keyWindow?.rootViewController
      ?? registeredViewController?.viewIfLoaded?.window?.rootViewController
    guard var current = root else {
      return nil
    }
    while true {
      if let presented = current.presentedViewController,
         !presented.isBeingDismissed {
        current = presented
      } else if let navigation = current as? UINavigationController,
                let visible = navigation.visibleViewController {
        current = visible
      } else if let tabs = current as? UITabBarController,
                let selected = tabs.selectedViewController {
        current = selected
      } else {
        return current
      }
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController,
                      didPickDocumentsAt urls: [URL]) {
    guard let pending, picker === controller else { return }
    picker = nil // Consume this controller callback before starting asynchronous I/O.
    guard urls.count == 1 else {
      finish(token: pending.token, error: "io_error")
      return
    }
    switch pending.operation {
    case .pick(let maxBytes):
      guard let url = urls.first, url.pathExtension.lowercased() == "json" else {
        finish(token: pending.token, error: "io_error")
        return
      }
      readPickedFile(url, maxBytes: maxBytes, token: pending.token, access: pending.access)
    case .save:
      finish(token: pending.token, value: true)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let pending, picker === controller else { return }
    switch pending.operation {
    case .pick:
      finish(token: pending.token, value: nil)
    case .save:
      finish(token: pending.token, value: false)
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let pending, let picker,
          picker.presentationController === presentationController else { return }
    switch pending.operation {
    case .pick:
      finish(token: pending.token, value: nil)
    case .save:
      finish(token: pending.token, value: false)
    }
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

  private func isCurrent(_ token: UUID,
                         picker candidate: UIDocumentPickerViewController) -> Bool {
    pending?.token == token && picker === candidate
  }

  private func finish(token: UUID, value: Any?) {
    guard let current = pending, current.token == token else { return }
    let callback = current.result
    pending = nil
    picker = nil
    removeExportDirectory()
    current.access.cancel()
    callback(value)
  }

  private func finish(token: UUID, error code: String) {
    guard let current = pending, current.token == token else { return }
    let callback = current.result
    pending = nil
    picker = nil
    removeExportDirectory()
    current.access.cancel()
    callback(Self.flutterError(code))
  }

  private func removeExportDirectory() {
    guard let directory = exportDirectory else {
      return
    }
    exportDirectory = nil
    try? FileManager.default.removeItem(at: directory)
  }

  func close() {
    guard !closed else { return }
    closed = true
    let activePicker = picker
    if let token = pending?.token {
      finish(token: token, error: "unavailable")
    }
    picker = nil
    removeExportDirectory()
    activePicker?.dismiss(animated: false)
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if Thread.isMainThread {
      close()
    } else {
      DispatchQueue.main.async { self.close() }
    }
  }

  deinit {
    pending?.access.cancel()
    removeExportDirectory()
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
