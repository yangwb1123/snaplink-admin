#include "workspace_file_contract.h"

#include <cstdlib>
#include <iostream>

#ifdef _WIN32
#include <windows.h>
#include "workspace_file_io.h"
#include "workspace_file_worker.h"
void TestWindowsChannel();
#endif

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using workspace_files::ArgumentStatus;

void Check(bool condition) {
  if (!condition) {
    std::cerr << "Workspace native contract assertion failed\n";
    std::exit(EXIT_FAILURE);
  }
}

EncodableValue Pick(EncodableValue limit) {
  return EncodableValue(EncodableMap{{EncodableValue("maxBytes"), limit}});
}

void TestPick() {
  size_t maximum = 0;
  for (const auto& limit : {EncodableValue(int32_t{1}),
                            EncodableValue(int64_t{524288})}) {
    auto arguments = Pick(limit);
    Check(workspace_files::ParsePick(&arguments, &maximum) == ArgumentStatus::kOk);
  }
  Check(maximum == 524288);
  for (const auto& limit : {EncodableValue(true), EncodableValue(1.0),
                            EncodableValue("1"), EncodableValue(int32_t{0}),
                            EncodableValue(int64_t{524289})}) {
    auto arguments = Pick(limit);
    Check(workspace_files::ParsePick(&arguments, &maximum) == ArgumentStatus::kInvalid);
  }
  auto extra = EncodableValue(EncodableMap{
      {EncodableValue("maxBytes"), EncodableValue(int32_t{1})},
      {EncodableValue("path"), EncodableValue("ignored")}});
  Check(workspace_files::ParsePick(&extra, &maximum) == ArgumentStatus::kInvalid);
}

void TestSave() {
  using workspace_files::IsSafeFilename;
  Check(IsSafeFilename("workspace-task_1-A.json"));
  Check(IsSafeFilename("workspace-" + std::string(96, 'a') + ".json"));
  for (const std::string name : {"workspace-.json", "workspace-a.json\n",
                                 "../workspace-a.json", "workspace-a.JSON",
                                 "workspace-a/b.json"}) Check(!IsSafeFilename(name));
  Check(!IsSafeFilename("workspace-" + std::string(97, 'a') + ".json"));
  Check(!IsSafeFilename(std::string("workspace-a.json\0x", 18)));
  workspace_files::SaveRequest request;
  const auto save = [](EncodableValue bytes) {
    return EncodableValue(EncodableMap{
        {EncodableValue("filename"), EncodableValue("workspace-a.json")},
        {EncodableValue("bytes"), bytes}});
  };
  auto valid = save(EncodableValue(std::vector<uint8_t>{0, 255, 1}));
  Check(workspace_files::ParseSave(&valid, &request) == ArgumentStatus::kOk);
  Check(request.bytes == std::vector<uint8_t>({0, 255, 1}));
  auto large = save(EncodableValue(std::vector<uint8_t>(524289, 1)));
  Check(workspace_files::ParseSave(&large, &request) == ArgumentStatus::kTooLarge);
  for (const auto& bytes : {EncodableValue(std::vector<int32_t>{1}),
                            EncodableValue(flutter::EncodableList{}),
                            EncodableValue("text")}) {
    auto invalid = save(bytes);
    Check(workspace_files::ParseSave(&invalid, &request) == ArgumentStatus::kInvalid);
  }
}

#ifdef _WIN32
workspace_files::IoCompletion WaitForCompletion(
    const std::shared_ptr<workspace_files::IoWorker>& worker) {
  workspace_files::IoCompletion completion;
  const auto deadline = GetTickCount64() + 5000;
  while (GetTickCount64() < deadline) {
    if (worker->TakeCompletion(&completion)) return completion;
    Sleep(10);
  }
  Check(false);
  return completion;
}

void TestWindowsWorkerWakeup(const std::wstring& path) {
  const HWND window = CreateWindowExW(0, L"STATIC", L"Workspace native test", 0,
      0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);
  Check(window != nullptr);
  constexpr UINT message = WM_APP + 17;
  auto worker = std::make_shared<workspace_files::IoWorker>(
      window, message, false, 524288, path, std::vector<uint8_t>());
  Check(workspace_files::IoWorker::Start(worker));
  MSG wakeup{};
  bool received = false;
  const auto deadline = GetTickCount64() + 5000;
  while (GetTickCount64() < deadline) {
    if (PeekMessageW(&wakeup, window, message, message, PM_REMOVE)) {
      received = true;
      break;
    }
    Sleep(10);
  }
  Check(received && wakeup.wParam == 0 && wakeup.lParam == 0);
  const auto completion = WaitForCompletion(worker);
  Check(completion.status == workspace_files::IoStatus::kOk);
  Check(completion.bytes == std::vector<uint8_t>({9, 0, 255}));
  workspace_files::IoCompletion duplicate;
  Check(!worker->TakeCompletion(&duplicate));
  worker->Cancel();
  Check(!worker->TakeCompletion(&duplicate));
  Check(DestroyWindow(window) != FALSE);
}

void TestWindowsWorkers(const std::wstring& path) {
  using workspace_files::IoStatus;
  using workspace_files::IoWorker;
  const std::vector<uint8_t> bytes{9, 0, 255};
  auto save = std::make_shared<IoWorker>(nullptr, 0, true, 0, path, bytes);
  Check(IoWorker::Start(save));
  Check(WaitForCompletion(save).status == IoStatus::kOk);
  workspace_files::IoCompletion duplicate;
  Check(!save->TakeCompletion(&duplicate));
  auto read = std::make_shared<IoWorker>(nullptr, 0, false, 524288, path,
                                       std::vector<uint8_t>());
  Check(IoWorker::Start(read));
  const auto result = WaitForCompletion(read);
  Check(result.status == IoStatus::kOk && result.bytes == bytes);

  // A cancelled request can release its owner immediately; the worker cleans
  // up its own retained payload without touching the destination.
  auto cancelled = std::make_shared<IoWorker>(nullptr, 0, true, 0, path,
                                              std::vector<uint8_t>(524288, 65));
  std::weak_ptr<IoWorker> remaining = cancelled;
  cancelled->Cancel();
  Check(IoWorker::Start(cancelled));
  cancelled.reset();
  const auto deadline = GetTickCount64() + 5000;
  while (!remaining.expired() && GetTickCount64() < deadline) Sleep(10);
  Check(remaining.expired());
  std::vector<uint8_t> unchanged;
  Check(workspace_files::ReadJson(path, 524288, &unchanged) == IoStatus::kOk);
  Check(unchanged == bytes);
  TestWindowsWorkerWakeup(path);
}

void TestWindowsIo() {
  wchar_t directory[MAX_PATH + 1]{};
  wchar_t path[MAX_PATH + 1]{};
  Check(GetTempPathW(MAX_PATH, directory) != 0);
  Check(GetTempFileNameW(directory, L"wsp", 0, path) != 0);
  using workspace_files::IoStatus;
  std::vector<uint8_t> result;
  const std::vector<uint8_t> maximum(524288, 255);
  Check(workspace_files::SaveJson(path, maximum) == IoStatus::kOk);
  Check(workspace_files::ReadJson(path, 524288, &result) == IoStatus::kOk);
  Check(result == maximum);
  Check(workspace_files::ReadJson(path, 524287, &result) == IoStatus::kTooLarge);
  Check(result.empty());
  const std::vector<uint8_t> short_bytes{0, 1, 128, 255};
  Check(workspace_files::SaveJson(path, short_bytes) == IoStatus::kOk);
  Check(workspace_files::ReadJson(path, 524288, &result) == IoStatus::kOk);
  Check(result == short_bytes);  // Existing longer file was fully truncated.
  Check(workspace_files::SaveJson(directory, short_bytes) == IoStatus::kError);
  Check(workspace_files::ReadJson(directory, 524288, &result) == IoStatus::kError);
  Check(workspace_files::SaveJson(path, std::vector<uint8_t>(524289, 1)) ==
        IoStatus::kTooLarge);
  std::atomic_bool cancelled{true};
  Check(workspace_files::SaveJson(path, std::vector<uint8_t>{9}, &cancelled) ==
        IoStatus::kError);
  Check(workspace_files::ReadJson(path, 524288, &result, &cancelled) == IoStatus::kError);
  Check(result.empty());
  Check(workspace_files::ReadJson(path, 524288, &result) == IoStatus::kOk);
  Check(result == short_bytes);
  Check(workspace_files::ReadJson(L"NUL", 524288, &result) == IoStatus::kError);
  Check(workspace_files::SaveJson(L"NUL", short_bytes) == IoStatus::kError);
  Check(workspace_files::SaveJson(path, {}) == IoStatus::kOk);
  Check(workspace_files::ReadJson(path, 524288, &result) == IoStatus::kOk);
  Check(result.empty());
  TestWindowsWorkers(path);
  Check(DeleteFileW(path) != FALSE);
}
#endif

}  // namespace

int main() {
  TestPick();
  TestSave();
#ifdef _WIN32
  TestWindowsIo();
  std::cout << "Workspace Windows argument, I/O and worker tests passed\n";
  TestWindowsChannel();
#else
  std::cout << "Workspace Windows portable argument tests passed (I/O excluded)\n";
#endif
  return EXIT_SUCCESS;
}
