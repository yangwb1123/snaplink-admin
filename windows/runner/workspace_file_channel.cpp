#include "workspace_file_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include "workspace_file_contract.h"
#include "workspace_file_worker.h"

namespace workspace_files {

using flutter::EncodableValue;
using Result = flutter::MethodResult<EncodableValue>;
using Microsoft::WRL::ComPtr;

struct PendingCall {
  std::unique_ptr<Result> result;
  ComPtr<IFileDialog> dialog;
  bool save;
  size_t maximum;
  SaveRequest request;
  std::shared_ptr<IoWorker> worker;
};

struct ChannelState {
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  HWND parent;
  UINT completion_message;
  std::shared_ptr<PendingCall> pending;
  bool closed = false;
};

namespace {

constexpr char kChannel[] = "site.ywbsd.sso/agent_workspace_files";

void Finish(const std::shared_ptr<ChannelState>& state,
            const std::shared_ptr<PendingCall>& pending,
            const EncodableValue& value, const char* error = nullptr) {
  if (state->closed || state->pending != pending || !pending->result) return;
  state->pending.reset();
  auto result = std::move(pending->result);
  if (error != nullptr) result->Error(error, "Workspace file operation failed");
  else result->Success(value);
}

HRESULT ConfigureDialog(PendingCall* pending) {
  HRESULT status;
  if (pending->save) {
    status = CoCreateInstance(CLSID_FileSaveDialog, nullptr, CLSCTX_INPROC_SERVER,
                               IID_PPV_ARGS(pending->dialog.GetAddressOf()));
  } else {
    status = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                               IID_PPV_ARGS(pending->dialog.GetAddressOf()));
  }
  if (FAILED(status)) return status;
  FILEOPENDIALOGOPTIONS options = 0;
  status = pending->dialog->GetOptions(&options);
  if (FAILED(status)) return status;
  options |= FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR;
  options |= pending->save ? FOS_OVERWRITEPROMPT : FOS_FILEMUSTEXIST;
  status = pending->dialog->SetOptions(options);
  if (FAILED(status)) return status;
  const COMDLG_FILTERSPEC filters[] = {{L"JSON files", L"*.json"}};
  status = pending->dialog->SetFileTypes(1, filters);
  if (FAILED(status)) return status;
  status = pending->dialog->SetDefaultExtension(L"json");
  if (FAILED(status)) return status;
  if (pending->save) {
    // Suggested name was ASCII validated. The user's dialog rename is allowed.
    const std::wstring filename(pending->request.filename.begin(),
                                pending->request.filename.end());
    status = pending->dialog->SetFileName(filename.c_str());
  }
  return status;
}

void CompleteSelection(const std::shared_ptr<ChannelState>& state,
                       const std::shared_ptr<PendingCall>& pending) {
  ComPtr<IShellItem> item;
  PWSTR selected = nullptr;
  if (FAILED(pending->dialog->GetResult(item.GetAddressOf())) ||
      FAILED(item->GetDisplayName(SIGDN_FILESYSPATH, &selected)) ||
      selected == nullptr) {
    if (selected != nullptr) CoTaskMemFree(selected);
    Finish(state, pending, EncodableValue(), "io_error");
    return;
  }
  const std::wstring path(selected);
  CoTaskMemFree(selected);
  if (state->closed || state->pending != pending) return;
  pending->dialog.Reset();
  pending->worker = std::make_shared<IoWorker>(
      state->parent, state->completion_message, pending->save, pending->maximum,
      path, std::move(pending->request.bytes));
  if (!IoWorker::Start(pending->worker)) {
    Finish(state, pending, EncodableValue(), "io_error");
  }
}

void ShowDialog(const std::shared_ptr<ChannelState>& state,
                const std::shared_ptr<PendingCall>& pending) {
  if (FAILED(ConfigureDialog(pending.get()))) {
    Finish(state, pending, EncodableValue(), "unavailable");
    return;
  }
  if (state->closed || state->pending != pending) return;
  // Show pumps a nested Windows message loop. The shared owner survives window
  // destruction; cancellation/close consumes the response exactly once.
  const HRESULT status = pending->dialog->Show(state->parent);
  if (state->closed || state->pending != pending) return;
  if (status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    Finish(state, pending, pending->save ? EncodableValue(false) : EncodableValue());
  } else if (FAILED(status)) {
    Finish(state, pending, EncodableValue(), "io_error");
  } else {
    CompleteSelection(state, pending);
  }
}

void Handle(std::shared_ptr<ChannelState> state,
            const flutter::MethodCall<EncodableValue>& call,
            std::unique_ptr<Result> result) {
  if (state->closed) {
    result->Error("unavailable", "Workspace file channel is closing");
    return;
  }
  if (call.method_name() == "capabilities") {
    result->Success(EncodableValue(flutter::EncodableMap{
        {EncodableValue("version"), EncodableValue(int32_t{1})},
        {EncodableValue("pick"), EncodableValue(true)},
        {EncodableValue("save"), EncodableValue(true)}}));
    return;
  }
  const bool save = call.method_name() == "saveJson";
  if (!save && call.method_name() != "pickJson") {
    result->NotImplemented();
    return;
  }
  if (state->pending) {
    result->Error("busy", "Another workspace file operation is active");
    return;
  }
  auto pending = std::make_shared<PendingCall>();
  pending->save = save;
  pending->maximum = 0;
  const auto parsed = save ? ParseSave(call.arguments(), &pending->request) :
                             ParsePick(call.arguments(), &pending->maximum);
  if (parsed != ArgumentStatus::kOk) {
    result->Error(parsed == ArgumentStatus::kTooLarge ? "too_large" :
                   "invalid_arguments", "Invalid workspace file arguments");
    return;
  }
  pending->result = std::move(result);
  state->pending = pending;
  ShowDialog(state, pending);
}

}  // namespace

FileChannel::FileChannel(flutter::BinaryMessenger* messenger, HWND parent)
    : state_(std::make_shared<ChannelState>()) {
  state_->parent = parent;
  state_->completion_message = RegisterWindowMessageW(
      L"site.ywbsd.sso.agent_workspace_files.complete.v1");
  state_->closed = state_->completion_message == 0;
  state_->channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  state_->channel->SetMethodCallHandler(
      [state = state_](const auto& call, auto result) {
        Handle(state, call, std::move(result));
      });
}

bool FileChannel::HandleWindowMessage(UINT message) {
  // Result callbacks can reenter the host. Own state independently of this object
  // before consuming a completion or invoking Flutter.
  const auto state = state_;
  const auto pending = state->pending;
  if (!state->closed && pending && pending->worker) {
    IoCompletion completion;
    if (pending->worker->TakeCompletion(&completion)) {
      if (completion.status != IoStatus::kOk) {
        Finish(state, pending, EncodableValue(),
               completion.status == IoStatus::kTooLarge ? "too_large" : "io_error");
      } else {
        Finish(state, pending, pending->save ? EncodableValue(true) :
               EncodableValue(std::move(completion.bytes)));
      }
    }
  }
  // Checking all window messages also drains a completion if a wakeup could not
  // be posted because the Windows message queue was momentarily full.
  return state->completion_message != 0 && message == state->completion_message;
}

FileChannel::~FileChannel() {
  state_->closed = true;
  state_->channel->SetMethodCallHandler(nullptr);
  auto pending = std::move(state_->pending);
  if (pending) {
    if (pending->worker) pending->worker->Cancel();
    if (pending->result) {
      auto result = std::move(pending->result);
      result->Error("unavailable", "Workspace file channel is closing");
    }
    // Close can pump window messages. Consume the Flutter reply first, while
    // the engine is still owned by FlutterWindow::OnDestroy.
    if (pending->dialog) pending->dialog->Close(HRESULT_FROM_WIN32(ERROR_CANCELLED));
    pending->request.bytes.clear();
  }
}

}  // namespace workspace_files
