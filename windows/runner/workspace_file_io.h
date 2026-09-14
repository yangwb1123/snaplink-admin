#ifndef RUNNER_WORKSPACE_FILE_IO_H_
#define RUNNER_WORKSPACE_FILE_IO_H_

#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace workspace_files {

enum class IoStatus { kOk, kTooLarge, kError };
IoStatus ReadJson(const std::wstring& path, size_t maximum,
                  std::vector<uint8_t>* bytes,
                  const std::atomic_bool* cancelled = nullptr);
IoStatus SaveJson(const std::wstring& path, const std::vector<uint8_t>& bytes,
                  const std::atomic_bool* cancelled = nullptr);

}  // namespace workspace_files

#endif  // RUNNER_WORKSPACE_FILE_IO_H_
