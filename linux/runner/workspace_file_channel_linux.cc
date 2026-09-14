#include "workspace_file_channel_linux.h"

#include "workspace_file_contract_linux.h"
#include "workspace_file_io_linux.h"

#include <cstring>

struct WorkspacePendingCall;
struct WorkspaceFileChannel {
  FlMethodChannel* channel;
  GtkWindow* parent;
  WorkspacePendingCall* pending;
  WorkspaceFileChooserFactory factory;
  FlBinaryMessenger* messenger;
};
struct WorkspacePendingCall {
  WorkspaceFileChannel* owner;
  FlMethodCall* call;
  GtkFileChooserNative* dialog;
  gboolean save;
  uint32_t max_bytes;
  GBytes* bytes;
  GTask* io_task;
};

struct WorkspaceIoJob {
  // Accessed only on GTK's main context, never by the worker.
  WorkspacePendingCall* pending;
  GFile* file;
  GBytes* input;
  gboolean save;
  uint32_t max_bytes;
  WorkspaceFileIoStatus status;
  GBytes* output;
};

namespace {

constexpr char kWorkspaceChannelName[] = "site.ywbsd.sso/agent_workspace_files";

void CancelPendingIo(WorkspacePendingCall* pending) {
  if (pending->io_task == nullptr) return;
  auto* job = static_cast<WorkspaceIoJob*>(g_task_get_task_data(pending->io_task));
  job->pending = nullptr;
  g_cancellable_cancel(g_task_get_cancellable(pending->io_task));
  g_clear_object(&pending->io_task);
}

void RespondError(FlMethodCall* call, const char* code, const char* message) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_error(call, code, message, nullptr, &error)) {
    g_warning("Workspace channel response failed");
  }
}

void RespondSuccess(FlMethodCall* call, FlValue* value) {
  g_autoptr(FlValue) owned_value = value;
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(call, owned_value, &error)) {
    g_warning("Workspace channel response failed");
  }
}

void FinishPending(WorkspacePendingCall* pending, FlValue* value,
                   const char* error_code = nullptr,
                   const char* error_message = nullptr) {
  WorkspaceFileChannel* owner = pending->owner;
  if (owner != nullptr) owner->pending = nullptr;
  CancelPendingIo(pending);
  g_signal_handlers_disconnect_by_data(pending->dialog, pending);
  gtk_native_dialog_hide(GTK_NATIVE_DIALOG(pending->dialog));
  if (error_code != nullptr) {
    RespondError(pending->call, error_code, error_message);
  } else {
    RespondSuccess(pending->call, value);
    value = nullptr;
  }
  if (value != nullptr) fl_value_unref(value);
  g_object_unref(pending->call);
  g_object_unref(pending->dialog);
  if (pending->bytes != nullptr) g_bytes_unref(pending->bytes);
  delete pending;
}

void DestroyIoJob(gpointer data) {
  auto* job = static_cast<WorkspaceIoJob*>(data);
  g_object_unref(job->file);
  if (job->input != nullptr) g_bytes_unref(job->input);
  if (job->output != nullptr) g_bytes_unref(job->output);
  delete job;
}

void RunIo(GTask* task, gpointer, gpointer task_data, GCancellable* cancellable) {
  auto* job = static_cast<WorkspaceIoJob*>(task_data);
  if (job->save) {
    gsize length = 0;
    const auto* bytes = static_cast<const uint8_t*>(
        g_bytes_get_data(job->input, &length));
    job->status = SaveWorkspaceJson(job->file, bytes, length, cancellable);
  } else {
    job->status = ReadWorkspaceJson(job->file, job->max_bytes, &job->output,
                                    cancellable);
  }
  g_task_return_boolean(task, TRUE);
}

void IoComplete(GObject*, GAsyncResult* result, gpointer) {
  auto* task = G_TASK(result);
  auto* job = static_cast<WorkspaceIoJob*>(g_task_get_task_data(task));
  WorkspacePendingCall* pending = job->pending;
  if (pending == nullptr) return;  // Closed owner; no GTK or messenger access.
  job->pending = nullptr;
  g_autoptr(GError) error = nullptr;
  const gboolean completed = g_task_propagate_boolean(task, &error);
  if (!completed || job->status == WorkspaceFileIoStatus::kIoError) {
    FinishPending(pending, nullptr, "io_error", "workspace file operation failed");
  } else if (job->status == WorkspaceFileIoStatus::kTooLarge) {
    FinishPending(pending, nullptr, "too_large", "workspace file exceeds the size limit");
  } else if (job->save) {
    FinishPending(pending, fl_value_new_bool(TRUE));
  } else {
    FinishPending(pending, fl_value_new_uint8_list_from_bytes(job->output));
  }
}

void StartIo(WorkspacePendingCall* pending, GFile* file) {
  g_signal_handlers_disconnect_by_data(pending->dialog, pending);
  gtk_native_dialog_hide(GTK_NATIVE_DIALOG(pending->dialog));
  g_autoptr(GCancellable) cancellable = g_cancellable_new();
  pending->io_task = g_task_new(nullptr, cancellable, IoComplete, nullptr);
  auto* job = new WorkspaceIoJob{
      pending, G_FILE(g_object_ref(file)),
      pending->bytes == nullptr ? nullptr : g_bytes_ref(pending->bytes),
      pending->save, pending->max_bytes, WorkspaceFileIoStatus::kIoError, nullptr};
  g_task_set_task_data(pending->io_task, job, DestroyIoJob);
  g_task_run_in_thread(pending->io_task, RunIo);
}

void NativeDialogResponse(GtkNativeDialog* native_dialog, int response,
                          gpointer user_data) {
  auto* pending = static_cast<WorkspacePendingCall*>(user_data);
  if (pending->owner == nullptr || pending->owner->pending != pending ||
      GTK_NATIVE_DIALOG(pending->dialog) != native_dialog) return;
  if (response != GTK_RESPONSE_ACCEPT) {
    FinishPending(pending, pending->save ? fl_value_new_bool(FALSE)
                                        : fl_value_new_null());
    return;
  }
  g_autoptr(GFile) file = gtk_file_chooser_get_file(
      GTK_FILE_CHOOSER(native_dialog));
  if (file == nullptr) {
    FinishPending(pending, nullptr, "io_error", "workspace file is unavailable");
    return;
  }
  StartIo(pending, file);
}

FlValue* CapabilitiesValue() {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(result, "version", fl_value_new_int(1));
  fl_value_set_string_take(result, "pick", fl_value_new_bool(TRUE));
  fl_value_set_string_take(result, "save", fl_value_new_bool(TRUE));
  return result;
}

void RespondArgumentError(FlMethodCall* call,
                          WorkspaceArgumentStatus status) {
  if (status == WorkspaceArgumentStatus::kTooLarge) {
    RespondError(call, "too_large", "workspace file exceeds the size limit");
  } else {
    RespondError(call, "invalid_arguments", "invalid workspace file arguments");
  }
}

GtkFileChooserNative* CreateChooser(GtkWindow* parent, gboolean save,
                                    const gchar* filename) {
  GtkFileChooserNative* chooser = gtk_file_chooser_native_new(
      save ? "Save workspace JSON" : "Open workspace JSON", parent,
      save ? GTK_FILE_CHOOSER_ACTION_SAVE : GTK_FILE_CHOOSER_ACTION_OPEN,
      save ? "Save" : "Open", "Cancel");
  gtk_file_chooser_set_local_only(GTK_FILE_CHOOSER(chooser), TRUE);
  GtkFileFilter* filter = gtk_file_filter_new();
  gtk_file_filter_set_name(filter, "JSON files");
  gtk_file_filter_add_mime_type(filter, "application/json");
  gtk_file_filter_add_pattern(filter, "*.json");
  gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(chooser), filter);
  if (save) {
    gtk_file_chooser_set_do_overwrite_confirmation(
        GTK_FILE_CHOOSER(chooser), TRUE);
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(chooser), filename);
  }
  return chooser;
}

void StartChooser(WorkspaceFileChannel* state, FlMethodCall* call,
                  gboolean save, uint32_t max_bytes, const gchar* filename,
                  GBytes* bytes) {
  auto* pending = new WorkspacePendingCall{
      state, FL_METHOD_CALL(g_object_ref(call)),
      state->factory(state->parent, save, filename), save, max_bytes, bytes,
      nullptr};
  state->pending = pending;
  g_signal_connect(pending->dialog, "response",
                   G_CALLBACK(NativeDialogResponse), pending);
  gtk_native_dialog_show(GTK_NATIVE_DIALOG(pending->dialog));
}

void MethodCallHandler(FlMethodChannel*, FlMethodCall* call,
                       gpointer user_data) {
  auto* state = static_cast<WorkspaceFileChannel*>(user_data);
  const gchar* method = fl_method_call_get_name(call);
  if (g_strcmp0(method, "capabilities") == 0) {
    RespondSuccess(call, CapabilitiesValue());
    return;
  }
  const gboolean is_pick = g_strcmp0(method, "pickJson") == 0;
  const gboolean is_save = g_strcmp0(method, "saveJson") == 0;
  if (!is_pick && !is_save) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_not_implemented_response_new());
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond(call, response, &error)) {
      g_warning("Workspace channel response failed");
    }
    return;
  }
  if (state->pending != nullptr) {
    RespondError(call, "busy", "another workspace file operation is active");
    return;
  }
  if (is_pick) {
    uint32_t max_bytes = 0;
    const WorkspaceArgumentStatus status = ParseWorkspacePickArguments(
        fl_method_call_get_args(call), &max_bytes);
    if (status != WorkspaceArgumentStatus::kOk) {
      RespondArgumentError(call, status);
      return;
    }
    StartChooser(state, call, FALSE, max_bytes, nullptr, nullptr);
    return;
  }
  WorkspaceSaveRequest request{};
  const WorkspaceArgumentStatus status = ParseWorkspaceSaveArguments(
      fl_method_call_get_args(call), &request);
  if (status != WorkspaceArgumentStatus::kOk) {
    RespondArgumentError(call, status);
    return;
  }
  GBytes* bytes = g_bytes_new(request.bytes, request.length);
  StartChooser(state, call, TRUE, 0, request.filename, bytes);
}

}  // namespace

WorkspaceFileChannel* WorkspaceFileChannelCreate(FlEngine* engine,
                                                 GtkWindow* parent) {
  if (engine == nullptr || parent == nullptr) return nullptr;
  return WorkspaceFileChannelCreateForMessenger(
      fl_engine_get_binary_messenger(engine), parent);
}

WorkspaceFileChannel* WorkspaceFileChannelCreateForMessenger(
    FlBinaryMessenger* messenger, GtkWindow* parent,
    WorkspaceFileChooserFactory factory) {
  if (messenger == nullptr || parent == nullptr) return nullptr;
  auto* state = new WorkspaceFileChannel{
      nullptr, GTK_WINDOW(g_object_ref(parent)), nullptr,
      factory == nullptr ? CreateChooser : factory,
      FL_BINARY_MESSENGER(g_object_ref(messenger))};
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  state->channel = fl_method_channel_new(
      messenger, kWorkspaceChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      state->channel, MethodCallHandler, state, nullptr);
  return state;
}

void WorkspaceFileChannelDestroy(WorkspaceFileChannel* state) {
  if (state == nullptr) return;
  if (state->pending != nullptr) {
    WorkspacePendingCall* pending = state->pending;
    pending->owner = nullptr;
    CancelPendingIo(pending);
    g_signal_handlers_disconnect_by_data(pending->dialog, pending);
    gtk_native_dialog_hide(GTK_NATIVE_DIALOG(pending->dialog));
    RespondError(pending->call, "unavailable", "workspace channel is closing");
    g_object_unref(pending->call);
    g_object_unref(pending->dialog);
    if (pending->bytes != nullptr) g_bytes_unref(pending->bytes);
    delete pending;
    state->pending = nullptr;
  }
  fl_method_channel_set_method_call_handler(state->channel, nullptr, nullptr,
                                           nullptr);
  fl_binary_messenger_set_message_handler_on_channel(
      state->messenger, kWorkspaceChannelName, nullptr, nullptr, nullptr);
  g_object_unref(state->channel);
  g_object_unref(state->messenger);
  g_object_unref(state->parent);
  delete state;
}
