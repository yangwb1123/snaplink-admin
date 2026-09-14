#include "workspace_file_io_linux.h"

#include <algorithm>
#include <array>
#include <cerrno>
#include <fcntl.h>
#include <limits>
#include <sys/stat.h>
#include <unistd.h>

namespace {

constexpr size_t kReadChunkBytes = 32 * 1024;

}  // namespace

WorkspaceFileIoStatus ReadWorkspaceJson(GFile* file, size_t max_bytes,
                                        GBytes** result, GCancellable* cancellable) {
  if (result == nullptr || file == nullptr || max_bytes == 0 ||
      max_bytes > 512 * 1024) {
    return WorkspaceFileIoStatus::kIoError;
  }
  *result = nullptr;
  if (g_cancellable_is_cancelled(cancellable)) return WorkspaceFileIoStatus::kIoError;
  g_autofree gchar* path = g_file_get_path(file);
  if (path == nullptr) return WorkspaceFileIoStatus::kIoError;
  // O_NONBLOCK prevents a chooser race that replaces a checked regular file
  // with a FIFO or device from blocking the worker. Symlinks are allowed
  // only when their opened target is still a regular file.
  const int descriptor = open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
  if (descriptor < 0) return WorkspaceFileIoStatus::kIoError;
  struct stat metadata {};
  if (fstat(descriptor, &metadata) != 0 || !S_ISREG(metadata.st_mode)) {
    close(descriptor);
    return WorkspaceFileIoStatus::kIoError;
  }

  GByteArray* buffer = g_byte_array_sized_new(max_bytes);
  std::array<uint8_t, kReadChunkBytes> chunk{};
  while (buffer->len <= max_bytes) {
    if (g_cancellable_is_cancelled(cancellable)) {
      g_byte_array_unref(buffer);
      close(descriptor);
      return WorkspaceFileIoStatus::kIoError;
    }
    const size_t remaining = max_bytes + 1 - buffer->len;
    const size_t request = std::min(chunk.size(), remaining);
    const ssize_t count = read(descriptor, chunk.data(), request);
    if (count < 0) {
      if (errno == EINTR) continue;
      g_byte_array_unref(buffer);
      close(descriptor);
      return WorkspaceFileIoStatus::kIoError;
    }
    if (count == 0) break;
    g_byte_array_append(buffer, chunk.data(), static_cast<guint>(count));
  }
  const int close_status = close(descriptor);
  if (close_status != 0) {
    g_byte_array_unref(buffer);
    return WorkspaceFileIoStatus::kIoError;
  }
  if (buffer->len > max_bytes) {
    g_byte_array_unref(buffer);
    return WorkspaceFileIoStatus::kTooLarge;
  }
  *result = g_byte_array_free_to_bytes(buffer);
  return WorkspaceFileIoStatus::kOk;
}

WorkspaceFileIoStatus SaveWorkspaceJson(GFile* file, const uint8_t* bytes,
                                        size_t length, GCancellable* cancellable) {
  if (file == nullptr || (bytes == nullptr && length != 0) ||
      length > 512 * 1024) {
    return WorkspaceFileIoStatus::kIoError;
  }
  if (g_cancellable_is_cancelled(cancellable)) return WorkspaceFileIoStatus::kIoError;
  g_autofree gchar* path = g_file_get_path(file);
  if (path == nullptr) return WorkspaceFileIoStatus::kIoError;
  struct stat metadata {};
  if (lstat(path, &metadata) == 0 && !S_ISREG(metadata.st_mode)) {
    return WorkspaceFileIoStatus::kIoError;
  }
  g_autoptr(GError) error = nullptr;
  g_autoptr(GFileOutputStream) stream = g_file_replace(
      file, nullptr, FALSE,
      static_cast<GFileCreateFlags>(G_FILE_CREATE_PRIVATE |
                                    G_FILE_CREATE_REPLACE_DESTINATION),
      cancellable, &error);
  if (stream == nullptr) return WorkspaceFileIoStatus::kIoError;
  gsize written = 0;
  if (!g_output_stream_write_all(G_OUTPUT_STREAM(stream), bytes, length,
                                 &written, cancellable, &error) ||
      written != length ||
      !g_output_stream_flush(G_OUTPUT_STREAM(stream), cancellable, &error) ||
      !g_output_stream_close(G_OUTPUT_STREAM(stream), cancellable, &error)) {
    return WorkspaceFileIoStatus::kIoError;
  }
  return WorkspaceFileIoStatus::kOk;
}
