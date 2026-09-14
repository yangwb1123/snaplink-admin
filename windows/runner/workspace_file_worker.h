#ifndef RUNNER_WORKSPACE_FILE_WORKER_H_
#define RUNNER_WORKSPACE_FILE_WORKER_H_

#include <windows.h>

#include <atomic>
#include <memory>
#include <mutex>

#include "workspace_file_io.h"

namespace workspace_files {

struct IoCompletion {
  IoStatus status = IoStatus::kError;
  std::vector<uint8_t> bytes;
};

// Contains no Flutter result, messenger or COM object. A worker may safely
// outlive its window while a filesystem driver finishes a cancelled operation.
class IoWorker {
 public:
  IoWorker(HWND parent, UINT message, bool save, size_t maximum,
           std::wstring path, std::vector<uint8_t> bytes);
  static bool Start(const std::shared_ptr<IoWorker>& worker);
  void Cancel();
  bool TakeCompletion(IoCompletion* result);

 private:
  static unsigned __stdcall ThreadEntry(void* context);
  void Run();

  const HWND parent_;
  const UINT message_;
  const bool save_;
  const size_t maximum_;
  std::wstring path_;
  std::vector<uint8_t> input_;
  std::atomic_bool cancelled_{false};
  std::mutex mutex_;
  HANDLE worker_thread_ = nullptr;
  bool completed_ = false;
  IoCompletion completion_;
};

}  // namespace workspace_files

#endif  // RUNNER_WORKSPACE_FILE_WORKER_H_
