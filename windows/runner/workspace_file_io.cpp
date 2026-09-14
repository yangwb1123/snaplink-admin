#include "workspace_file_io.h"

#include <windows.h>

#include <algorithm>
#include <array>

#include "workspace_file_contract.h"

namespace workspace_files {
namespace {

bool IsCancelled(const std::atomic_bool* cancelled) {
  return cancelled != nullptr && cancelled->load();
}

bool IsRegularFile(HANDLE file) {
  BY_HANDLE_FILE_INFORMATION information{};
  return GetFileType(file) == FILE_TYPE_DISK &&
         GetFileInformationByHandle(file, &information) &&
         (information.dwFileAttributes &
          (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) == 0;
}

}  // namespace

IoStatus ReadJson(const std::wstring& path, size_t maximum,
                  std::vector<uint8_t>* bytes, const std::atomic_bool* cancelled) {
  if (bytes == nullptr || maximum == 0 || maximum > kMaxBytes) {
    return IoStatus::kError;
  }
  bytes->clear();
  if (IsCancelled(cancelled)) return IoStatus::kError;
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                            OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (file == INVALID_HANDLE_VALUE) return IoStatus::kError;
  if (!IsRegularFile(file)) {
    CloseHandle(file);
    return IoStatus::kError;
  }
  std::array<uint8_t, 32 * 1024> chunk{};
  IoStatus status = IoStatus::kOk;
  while (bytes->size() <= maximum) {
    const DWORD requested = static_cast<DWORD>(
        std::min(chunk.size(), maximum + 1 - bytes->size()));
    DWORD count = 0;
    if (IsCancelled(cancelled) || !ReadFile(file, chunk.data(), requested, &count, nullptr)) {
      status = IoStatus::kError;
      break;
    }
    if (count == 0) break;
    bytes->insert(bytes->end(), chunk.begin(), chunk.begin() + count);
  }
  if (!CloseHandle(file) || IsCancelled(cancelled)) status = IoStatus::kError;
  if (status == IoStatus::kOk && bytes->size() > maximum) {
    status = IoStatus::kTooLarge;
  }
  if (status != IoStatus::kOk) bytes->clear();
  return status;
}

IoStatus SaveJson(const std::wstring& path, const std::vector<uint8_t>& bytes,
                  const std::atomic_bool* cancelled) {
  if (bytes.size() > kMaxBytes) return IoStatus::kTooLarge;
  if (IsCancelled(cancelled)) return IoStatus::kError;
  // OPEN_ALWAYS lets us inspect the actual handle before truncating. Refuse
  // reparse points and special handles even if the selected path is replaced.
  HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_ALWAYS,
                            FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (file == INVALID_HANDLE_VALUE) return IoStatus::kError;
  if (IsCancelled(cancelled) || !IsRegularFile(file) || !SetEndOfFile(file)) {
    CloseHandle(file);
    return IoStatus::kError;
  }
  size_t offset = 0;
  bool written = true;
  while (offset < bytes.size()) {
    const DWORD requested = static_cast<DWORD>(
        std::min<size_t>(32 * 1024, bytes.size() - offset));
    DWORD count = 0;
    if (IsCancelled(cancelled) || !WriteFile(file, bytes.data() + offset, requested, &count, nullptr) ||
        count == 0) {
      written = false;
      break;
    }
    offset += count;
  }
  const bool flushed = written && !IsCancelled(cancelled) && FlushFileBuffers(file);
  const bool closed = CloseHandle(file) != FALSE;
  return flushed && closed && !IsCancelled(cancelled) ? IoStatus::kOk : IoStatus::kError;
}

}  // namespace workspace_files
