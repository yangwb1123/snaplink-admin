#include "workspace_file_worker.h"

#include <process.h>

#include <utility>

namespace workspace_files {

IoWorker::IoWorker(HWND parent, UINT message, bool save, size_t maximum,
                   std::wstring path, std::vector<uint8_t> bytes)
    : parent_(parent), message_(message), save_(save), maximum_(maximum),
      path_(std::move(path)), input_(std::move(bytes)) {}

bool IoWorker::Start(const std::shared_ptr<IoWorker>& worker) {
  auto* context = new std::shared_ptr<IoWorker>(worker);
  const uintptr_t handle = _beginthreadex(nullptr, 0, ThreadEntry, context, 0, nullptr);
  if (handle == 0) {
    delete context;
    return false;
  }
  // The worker duplicates its own handle for cancellation. No UI-thread join.
  CloseHandle(reinterpret_cast<HANDLE>(handle));
  return true;
}

void IoWorker::Cancel() {
  cancelled_.store(true);
  std::lock_guard<std::mutex> lock(mutex_);
  if (worker_thread_ != nullptr) CancelSynchronousIo(worker_thread_);
  completion_.bytes.clear();
  completed_ = false;
}

bool IoWorker::TakeCompletion(IoCompletion* result) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (result == nullptr || !completed_ || cancelled_.load()) return false;
  *result = std::move(completion_);
  completed_ = false;
  return true;
}

unsigned __stdcall IoWorker::ThreadEntry(void* context) {
  std::unique_ptr<std::shared_ptr<IoWorker>> owned(
      static_cast<std::shared_ptr<IoWorker>*>(context));
  const auto worker = *owned;
  owned.reset();
  worker->Run();
  return 0;
}

void IoWorker::Run() {
  bool ready = false;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    ready = !cancelled_.load() && DuplicateHandle(
        GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(),
        &worker_thread_, 0, FALSE, DUPLICATE_SAME_ACCESS);
  }
  IoCompletion outcome;
  if (ready) {
    outcome.status = save_ ? SaveJson(path_, input_, &cancelled_) :
        ReadJson(path_, maximum_, &outcome.bytes, &cancelled_);
  }
  // Keep buffers alive until the kernel has returned from the I/O call, then
  // release the selected path and prompt/output payload before posting a wakeup.
  std::vector<uint8_t>().swap(input_);
  std::wstring().swap(path_);
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (worker_thread_ != nullptr) CloseHandle(worker_thread_);
    worker_thread_ = nullptr;
    if (!cancelled_.load()) {
      completion_ = std::move(outcome);
      completed_ = true;
    }
  }
  if (!cancelled_.load() && parent_ != nullptr) {
    // No pointer travels through the queue. A stale wakeup on a reused HWND
    // can only drain that window's current, independently owned completion.
    PostMessageW(parent_, message_, 0, 0);
  }
}

}  // namespace workspace_files
