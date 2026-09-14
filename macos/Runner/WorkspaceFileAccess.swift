import Darwin
import Foundation

enum WorkspaceFileFailure: Error {
  case tooLarge
  case io
}

/// One coordinator belongs to one request; cancellation never affects its successor.
final class WorkspaceFileAccess {
  private let coordinator = NSFileCoordinator(filePresenter: nil)
  private let lock = NSLock()
  private var cancelled = false

  func cancel() {
    lock.lock()
    cancelled = true
    lock.unlock()
    coordinator.cancel()
  }

  private func checkActive() throws {
    lock.lock()
    let isCancelled = cancelled
    lock.unlock()
    if isCancelled { throw WorkspaceFileFailure.io }
  }

  func read(_ url: URL, maxBytes: Int) throws -> Data {
    try checkActive()
    var outcome: Result<Data, Error>?
    var coordinationError: NSError?
    coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      coordinatedURL in
      outcome = Result<Data, Error> {
        try self.checkActive()
        return try Self.readBounded(coordinatedURL, maxBytes: maxBytes) {
          try self.checkActive()
        }
      }
    }
    guard coordinationError == nil, let outcome else { throw WorkspaceFileFailure.io }
    try checkActive()
    return try outcome.get()
  }

  func write(_ data: Data, to url: URL) throws {
    try checkActive()
    var outcome: Result<Void, Error>?
    var coordinationError: NSError?
    coordinator.coordinate(writingItemAt: url, options: .forReplacing,
                           error: &coordinationError) { coordinatedURL in
      outcome = Result<Void, Error> {
        try self.checkActive()
        // Foundation closes the temporary output before committing the atomic replacement.
        try data.write(to: coordinatedURL, options: .atomic)
      }
    }
    guard coordinationError == nil, let outcome else { throw WorkspaceFileFailure.io }
    try outcome.get()
    try checkActive()
  }

  static func collectBounded(maxBytes: Int, readChunk: (Int) throws -> Data?) throws -> Data {
    guard (1...524_288).contains(maxBytes) else { throw WorkspaceFileFailure.io }
    var data = Data()
    while data.count <= maxBytes {
      let remaining = maxBytes + 1 - data.count
      guard let chunk = try readChunk(min(64 * 1024, remaining)), !chunk.isEmpty else {
        break
      }
      guard chunk.count <= remaining else { throw WorkspaceFileFailure.tooLarge }
      data.append(chunk)
    }
    guard data.count <= maxBytes else { throw WorkspaceFileFailure.tooLarge }
    return data
  }

  static func readBounded(_ url: URL, maxBytes: Int,
                          checkActive: () throws -> Void = {}) throws -> Data {
    guard url.isFileURL else { throw WorkspaceFileFailure.io }
    // Open nonblocking, then inspect that same descriptor, so a FIFO/device cannot hang a read.
    let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else { return -1 }
      return Darwin.open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
    }
    guard descriptor >= 0 else { throw WorkspaceFileFailure.io }
    defer { Darwin.close(descriptor) }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0,
          (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw WorkspaceFileFailure.io }
    return try collectBounded(maxBytes: maxBytes) { requested in
      try checkActive()
      var bytes = [UInt8](repeating: 0, count: requested)
      var count: Int
      repeat {
        try checkActive()
        count = bytes.withUnsafeMutableBytes { buffer in
          Darwin.read(descriptor, buffer.baseAddress, requested)
        }
      } while count < 0 && errno == EINTR
      guard count >= 0 else { throw WorkspaceFileFailure.io }
      return count == 0 ? nil : Data(bytes.prefix(count))
    }
  }
}
