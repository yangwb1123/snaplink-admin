#include "workspace_file_contract_linux.h"
#include "workspace_file_channel_linux.h"
#include "workspace_file_io_linux.h"

#include <cstring>
#include <functional>
#include <glib/gstdio.h>
#include <string>
#include <sys/stat.h>
#include <vector>

namespace {

typedef struct _TestMessenger TestMessenger;
typedef struct _TestMessengerClass TestMessengerClass;

struct _TestMessenger {
  GObject parent_instance;
  FlBinaryMessengerMessageHandler handler;
  gpointer handler_data;
  GDestroyNotify handler_destroy;
  GBytes* response;
  unsigned responses;
};

struct _TestMessengerClass {
  GObjectClass parent_class;
};

static void TestMessengerInterfaceInit(FlBinaryMessengerInterface* interface);
G_DEFINE_TYPE_WITH_CODE(TestMessenger, test_messenger, G_TYPE_OBJECT,
                        G_IMPLEMENT_INTERFACE(fl_binary_messenger_get_type(),
                                              TestMessengerInterfaceInit))

void TestMessengerSetHandler(FlBinaryMessenger* messenger, const gchar*,
                             FlBinaryMessengerMessageHandler handler,
                             gpointer user_data, GDestroyNotify destroy) {
  auto* self = reinterpret_cast<TestMessenger*>(messenger);
  if (self->handler_destroy != nullptr) {
    self->handler_destroy(self->handler_data);
  }
  self->handler = handler;
  self->handler_data = user_data;
  self->handler_destroy = destroy;
}

gboolean TestMessengerSendResponse(FlBinaryMessenger* messenger,
                                   FlBinaryMessengerResponseHandle*,
                                   GBytes* response, GError**) {
  auto* self = reinterpret_cast<TestMessenger*>(messenger);
  ++self->responses;
  if (self->response != nullptr) g_bytes_unref(self->response);
  self->response = response == nullptr ? nullptr : g_bytes_ref(response);
  return TRUE;
}

void TestMessengerInterfaceInit(FlBinaryMessengerInterface* interface) {
  interface->set_message_handler_on_channel = TestMessengerSetHandler;
  interface->send_response = TestMessengerSendResponse;
}

void TestMessengerFinalize(GObject* object) {
  auto* self = reinterpret_cast<TestMessenger*>(object);
  if (self->handler_destroy != nullptr) {
    self->handler_destroy(self->handler_data);
  }
  if (self->response != nullptr) g_bytes_unref(self->response);
  G_OBJECT_CLASS(test_messenger_parent_class)->finalize(object);
}

static void test_messenger_class_init(TestMessengerClass* klass) {
  G_OBJECT_CLASS(klass)->finalize = TestMessengerFinalize;
}

static void test_messenger_init(TestMessenger* self) {
  self->handler = nullptr;
  self->handler_data = nullptr;
  self->handler_destroy = nullptr;
  self->response = nullptr;
  self->responses = 0;
}

void SendMethod(TestMessenger* messenger, FlStandardMethodCodec* codec,
                 const gchar* method, FlValue* arguments) {
  g_clear_pointer(&messenger->response, g_bytes_unref);
  FlMethodCodecClass* codec_class = FL_METHOD_CODEC_GET_CLASS(codec);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GBytes) request = codec_class->encode_method_call(
      FL_METHOD_CODEC(codec), method, arguments, &error);
  g_assert_no_error(error);
  g_assert_nonnull(request);
  g_assert_nonnull(messenger->handler);
  g_autoptr(FlBinaryMessengerResponseHandle) handle =
      FL_BINARY_MESSENGER_RESPONSE_HANDLE(
          g_object_new(fl_binary_messenger_response_handle_get_type(),
                       nullptr));
  messenger->handler(FL_BINARY_MESSENGER(messenger),
                     "site.ywbsd.sso/agent_workspace_files", request, handle,
                     messenger->handler_data);
}

FlMethodResponse* DecodeResponse(TestMessenger* messenger,
                                 FlStandardMethodCodec* codec) {
  FlMethodCodecClass* codec_class = FL_METHOD_CODEC_GET_CLASS(codec);
  g_autoptr(GError) error = nullptr;
  g_assert_nonnull(messenger->response);
  return codec_class->decode_response(FL_METHOD_CODEC(codec),
                                     messenger->response, &error);
}

FlMethodResponse* DispatchMethod(TestMessenger* messenger,
                                FlStandardMethodCodec* codec,
                                const gchar* method, FlValue* arguments) {
  SendMethod(messenger, codec, method, arguments);
  return DecodeResponse(messenger, codec);
}

FlValue* MakePickArguments(int64_t max_bytes) {
  FlValue* arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "maxBytes", fl_value_new_int(max_bytes));
  return arguments;
}

FlValue* MakeSaveArguments(const gchar* filename,
                           const std::vector<uint8_t>& bytes) {
  FlValue* arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "filename", fl_value_new_string(filename));
  fl_value_set_string_take(arguments, "bytes",
                           fl_value_new_uint8_list(bytes.data(), bytes.size()));
  return arguments;
}

void TestFilenameContract() {
  g_assert_true(IsSafeWorkspaceFilename("workspace-task_01-A.json"));
  g_assert_false(IsSafeWorkspaceFilename("workspace-.json"));
  g_assert_false(IsSafeWorkspaceFilename("../workspace-a.json"));
  g_assert_false(IsSafeWorkspaceFilename("workspace-a.JSON"));
  g_assert_false(IsSafeWorkspaceFilename("workspace-contains/slash.json"));
  g_assert_false(IsSafeWorkspaceFilename("workspace-a.json\n"));
  const std::string too_long = "workspace-" + std::string(97, 'a') + ".json";
  g_assert_false(IsSafeWorkspaceFilename(too_long.c_str()));
}

void TestArgumentContract() {
  uint32_t maximum = 0;
  g_autoptr(FlValue) pick = MakePickArguments(524288);
  g_assert_cmpint(static_cast<int>(ParseWorkspacePickArguments(pick, &maximum)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kOk));
  g_assert_cmpuint(maximum, ==, 524288);
  g_autoptr(FlValue) bad_pick = MakePickArguments(0);
  g_assert_cmpint(static_cast<int>(ParseWorkspacePickArguments(bad_pick,
                                                               &maximum)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kInvalidArguments));

  std::vector<uint8_t> small{0, 1, 255};
  g_autoptr(FlValue) save = MakeSaveArguments("workspace-run_2.json", small);
  WorkspaceSaveRequest request{};
  g_assert_cmpint(static_cast<int>(ParseWorkspaceSaveArguments(save, &request)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kOk));
  g_assert_cmpuint(request.length, ==, small.size());
  g_assert_cmpmem(request.bytes, request.length, small.data(), small.size());

  std::vector<uint8_t> large(kWorkspaceFileMaxBytes + 1, 7);
  g_autoptr(FlValue) too_large =
      MakeSaveArguments("workspace-run_2.json", large);
  g_assert_cmpint(static_cast<int>(ParseWorkspaceSaveArguments(too_large,
                                                               &request)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kTooLarge));
  for (FlValue* value : {fl_value_new_bool(TRUE), fl_value_new_float(1.0),
                         fl_value_new_int(524289)}) {
    g_autoptr(FlValue) invalid = fl_value_new_map();
    fl_value_set_string_take(invalid, "maxBytes", value);
    g_assert_cmpint(static_cast<int>(ParseWorkspacePickArguments(invalid, &maximum)),
                    ==, static_cast<int>(WorkspaceArgumentStatus::kInvalidArguments));
  }
  fl_value_set_string_take(pick, "path", fl_value_new_string("untrusted"));
  g_assert_cmpint(static_cast<int>(ParseWorkspacePickArguments(pick, &maximum)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kInvalidArguments));
  fl_value_set_string_take(save, "bytes", fl_value_new_list());
  g_assert_cmpint(static_cast<int>(ParseWorkspaceSaveArguments(save, &request)),
                  ==, static_cast<int>(WorkspaceArgumentStatus::kInvalidArguments));
}

void TestBoundedIo() {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* directory = g_dir_make_tmp("workspace-files-XXXXXX", &error);
  g_assert_no_error(error);
  g_assert_nonnull(directory);
  g_autofree gchar* input_path = g_build_filename(directory, "input.json", nullptr);
  g_autofree gchar* output_path = g_build_filename(directory, "output.json", nullptr);
  g_autofree gchar* fifo_path = g_build_filename(directory, "input.fifo", nullptr);
  const gchar input[] = "{\"schema\":1}";
  g_assert_true(g_file_set_contents(input_path, input, sizeof(input) - 1, &error));
  g_assert_no_error(error);

  g_autoptr(GFile) input_file = g_file_new_for_path(input_path);
  GBytes* result = nullptr;
  g_assert_cmpint(static_cast<int>(ReadWorkspaceJson(input_file, 32, &result)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kOk));
  g_autoptr(GBytes) owned_result = result;
  gsize result_length = 0;
  const gchar* data = static_cast<const gchar*>(
      g_bytes_get_data(owned_result, &result_length));
  g_assert_cmpuint(result_length, ==, sizeof(input) - 1);
  g_assert_cmpmem(data, result_length, input, sizeof(input) - 1);

  g_assert_cmpint(static_cast<int>(ReadWorkspaceJson(input_file, 4, &result)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kTooLarge));
  g_assert_null(result);

  g_assert_cmpint(mkfifo(fifo_path, 0600), ==, 0);
  g_autoptr(GFile) fifo_file = g_file_new_for_path(fifo_path);
  g_assert_cmpint(static_cast<int>(ReadWorkspaceJson(fifo_file, 32, &result)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kIoError));
  g_assert_null(result);

  g_autoptr(GFile) output_file = g_file_new_for_path(output_path);
  const uint8_t output[] = {0, 17, 255, 42};
  g_assert_cmpint(static_cast<int>(SaveWorkspaceJson(
                      fifo_file, output, sizeof(output))),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kIoError));
  const std::vector<uint8_t> maximum(kWorkspaceFileMaxBytes, 251);
  g_assert_cmpint(static_cast<int>(SaveWorkspaceJson(
                      output_file, maximum.data(), maximum.size())),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kOk));
  g_assert_cmpint(static_cast<int>(ReadWorkspaceJson(
                      output_file, kWorkspaceFileMaxBytes, &result)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kOk));
  g_assert_cmpuint(g_bytes_get_size(result), ==, maximum.size());
  g_bytes_unref(result);
  g_assert_cmpint(static_cast<int>(SaveWorkspaceJson(
                      output_file, output, sizeof(output))),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kOk));
  g_autofree gchar* saved = nullptr;
  gsize saved_length = 0;
  g_assert_true(g_file_get_contents(output_path, &saved, &saved_length, &error));
  g_assert_no_error(error);
  g_assert_cmpuint(saved_length, ==, sizeof(output));
  g_assert_cmpmem(saved, saved_length, output, sizeof(output));
  g_autoptr(GCancellable) cancelled = g_cancellable_new();
  g_cancellable_cancel(cancelled);
  g_assert_cmpint(static_cast<int>(ReadWorkspaceJson(
                      output_file, kWorkspaceFileMaxBytes, &result, cancelled)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kIoError));
  g_assert_null(result);
  g_assert_cmpint(static_cast<int>(SaveWorkspaceJson(
                      output_file, maximum.data(), maximum.size(), cancelled)),
                  ==, static_cast<int>(WorkspaceFileIoStatus::kIoError));

  g_assert_true(g_file_delete(input_file, nullptr, nullptr));
  g_assert_true(g_file_delete(output_file, nullptr, nullptr));
  g_assert_true(g_file_delete(fifo_file, nullptr, nullptr));
  g_assert_true(g_rmdir(directory) == 0);
}

void TestMethodChannelContract() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  auto* messenger = reinterpret_cast<TestMessenger*>(
      g_object_new(test_messenger_get_type(), nullptr));
  WorkspaceFileChannel* channel = WorkspaceFileChannelCreateForMessenger(
      FL_BINARY_MESSENGER(messenger), GTK_WINDOW(window));
  g_assert_nonnull(channel);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  g_autoptr(FlMethodResponse) capabilities =
      DispatchMethod(messenger, codec, "capabilities", nullptr);
  g_assert_true(FL_IS_METHOD_SUCCESS_RESPONSE(capabilities));
  g_autoptr(GError) error = nullptr;
  FlValue* result = fl_method_response_get_result(capabilities, &error);
  g_assert_no_error(error);
  g_assert_cmpint(fl_value_get_int(fl_value_lookup_string(result, "version")),
                  ==, 1);
  g_assert_true(fl_value_get_bool(fl_value_lookup_string(result, "pick")));
  g_assert_true(fl_value_get_bool(fl_value_lookup_string(result, "save")));

  g_bytes_unref(messenger->response);
  messenger->response = nullptr;
  g_autoptr(FlValue) invalid_pick = MakePickArguments(0);
  g_autoptr(FlMethodResponse) rejected =
      DispatchMethod(messenger, codec, "pickJson", invalid_pick);
  g_assert_true(FL_IS_METHOD_ERROR_RESPONSE(rejected));
  g_assert_cmpstr(fl_method_error_response_get_code(
                      FL_METHOD_ERROR_RESPONSE(rejected)),
                  ==, "invalid_arguments");

  g_bytes_unref(messenger->response);
  messenger->response = nullptr;
  g_autoptr(FlMethodResponse) unknown =
      DispatchMethod(messenger, codec, "unrecognized", nullptr);
  g_assert_null(unknown);

  WorkspaceFileChannelDestroy(channel);
  gtk_widget_destroy(window);
  g_object_unref(messenger);
}

GtkFileChooserNative* last_chooser = nullptr;

GtkFileChooserNative* CaptureChooser(GtkWindow* parent, gboolean save,
                                     const gchar*) {
  last_chooser = gtk_file_chooser_native_new(
      "Workspace test", parent, save ? GTK_FILE_CHOOSER_ACTION_SAVE :
                                        GTK_FILE_CHOOSER_ACTION_OPEN,
      "Select", "Cancel");
  g_object_ref(last_chooser);  // Test keeps old dialogs alive for stale callbacks.
  return last_chooser;
}

void AssertResponseError(TestMessenger* messenger, FlStandardMethodCodec* codec,
                         const char* code) {
  g_autoptr(FlMethodResponse) response = DecodeResponse(messenger, codec);
  g_assert_true(FL_IS_METHOD_ERROR_RESPONSE(response));
  g_assert_cmpstr(fl_method_error_response_get_code(
                      FL_METHOD_ERROR_RESPONSE(response)), ==, code);
}

void TestDialogLifecycle() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  auto* messenger = reinterpret_cast<TestMessenger*>(
      g_object_new(test_messenger_get_type(), nullptr));
  auto* channel = WorkspaceFileChannelCreateForMessenger(
      FL_BINARY_MESSENGER(messenger), GTK_WINDOW(window), CaptureChooser);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlValue) pick = MakePickArguments(524288);
  SendMethod(messenger, codec, "pickJson", pick);
  g_assert_null(messenger->response);
  GtkFileChooserNative* first = last_chooser;
  SendMethod(messenger, codec, "pickJson", pick);
  AssertResponseError(messenger, codec, "busy");
  g_signal_emit_by_name(first, "response", GTK_RESPONSE_CANCEL);
  g_autoptr(FlMethodResponse) cancelled = DecodeResponse(messenger, codec);
  g_assert_true(FL_IS_METHOD_SUCCESS_RESPONSE(cancelled));
  FlValue* value = fl_method_response_get_result(cancelled, nullptr);
  g_assert_cmpint(fl_value_get_type(value), ==, FL_VALUE_TYPE_NULL);

  g_autoptr(FlValue) save = MakeSaveArguments("workspace-a.json", {0, 255});
  SendMethod(messenger, codec, "saveJson", save);
  g_assert_null(messenger->response);
  GtkFileChooserNative* second = last_chooser;
  const unsigned responses = messenger->responses;
  g_signal_emit_by_name(first, "response", GTK_RESPONSE_ACCEPT);
  g_assert_cmpuint(messenger->responses, ==, responses);
  g_signal_emit_by_name(second, "response", GTK_RESPONSE_CANCEL);
  g_autoptr(FlMethodResponse) save_cancelled = DecodeResponse(messenger, codec);
  value = fl_method_response_get_result(save_cancelled, nullptr);
  g_assert_cmpint(fl_value_get_type(value), ==, FL_VALUE_TYPE_BOOL);
  g_assert_false(fl_value_get_bool(value));

  SendMethod(messenger, codec, "pickJson", pick);
  GtkFileChooserNative* third = last_chooser;
  WorkspaceFileChannelDestroy(channel);
  AssertResponseError(messenger, codec, "unavailable");
  const unsigned closed_responses = messenger->responses;
  g_signal_emit_by_name(third, "response", GTK_RESPONSE_ACCEPT);
  g_assert_cmpuint(messenger->responses, ==, closed_responses);
  g_assert_null(messenger->handler);
  g_object_unref(first);
  g_object_unref(second);
  g_object_unref(third);
  gtk_widget_destroy(window);
  g_object_unref(messenger);
}

void WaitFor(const std::function<bool()>& ready) {
  const gint64 deadline = g_get_monotonic_time() + 3 * G_TIME_SPAN_SECOND;
  while (!ready() && g_get_monotonic_time() < deadline) {
    while (g_main_context_iteration(nullptr, FALSE)) {}
    g_usleep(1000);
  }
  g_assert_true(ready());
}

void SelectFile(GtkFileChooserNative* chooser, GFile* file) {
  g_assert_true(gtk_file_chooser_set_file(GTK_FILE_CHOOSER(chooser), file, nullptr));
  WaitFor([chooser, file]() {
    g_autoptr(GFile) selected = gtk_file_chooser_get_file(GTK_FILE_CHOOSER(chooser));
    return selected != nullptr && g_file_equal(selected, file);
  });
}

void TestAsyncIoLifecycle() {
  g_autofree gchar* directory = g_dir_make_tmp("workspace-async-XXXXXX", nullptr);
  g_assert_nonnull(directory);
  g_autofree gchar* path = g_build_filename(directory, "input.json", nullptr);
  const gchar input[] = "{\"value\":1}";
  g_assert_true(g_file_set_contents(path, input, sizeof(input) - 1, nullptr));
  g_autoptr(GFile) file = g_file_new_for_path(path);
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  auto* messenger = reinterpret_cast<TestMessenger*>(
      g_object_new(test_messenger_get_type(), nullptr));
  auto* channel = WorkspaceFileChannelCreateForMessenger(
      FL_BINARY_MESSENGER(messenger), GTK_WINDOW(window), CaptureChooser);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlValue) pick = MakePickArguments(524288);
  SendMethod(messenger, codec, "pickJson", pick);
  GtkFileChooserNative* first = last_chooser;
  SelectFile(first, file);
  g_signal_emit_by_name(first, "response", GTK_RESPONSE_ACCEPT);
  g_assert_null(messenger->response);  // I/O cannot reply synchronously on GTK.
  SendMethod(messenger, codec, "pickJson", pick);
  AssertResponseError(messenger, codec, "busy");
  const unsigned busy_responses = messenger->responses;
  WaitFor([messenger, busy_responses]() {
    return messenger->responses > busy_responses;
  });
  g_autoptr(FlMethodResponse) read = DecodeResponse(messenger, codec);
  FlValue* bytes = fl_method_response_get_result(read, nullptr);
  g_assert_cmpint(fl_value_get_type(bytes), ==, FL_VALUE_TYPE_UINT8_LIST);
  g_assert_cmpmem(fl_value_get_uint8_list(bytes), fl_value_get_length(bytes),
                  input, sizeof(input) - 1);

  g_autoptr(FlValue) save = MakeSaveArguments("workspace-output.json", {0, 255, 1});
  SendMethod(messenger, codec, "saveJson", save);
  GtkFileChooserNative* save_chooser = last_chooser;
  SelectFile(save_chooser, file);  // User selected name differs from suggestion.
  const unsigned before_save = messenger->responses;
  g_signal_emit_by_name(save_chooser, "response", GTK_RESPONSE_ACCEPT);
  g_assert_null(messenger->response);
  WaitFor([messenger, before_save]() {
    return messenger->responses > before_save;
  });
  g_autoptr(FlMethodResponse) saved = DecodeResponse(messenger, codec);
  FlValue* saved_value = fl_method_response_get_result(saved, nullptr);
  g_assert_true(fl_value_get_bool(saved_value));
  g_autofree gchar* saved_bytes = nullptr;
  gsize saved_length = 0;
  g_assert_true(g_file_get_contents(path, &saved_bytes, &saved_length, nullptr));
  const uint8_t expected[] = {0, 255, 1};
  g_assert_cmpmem(saved_bytes, saved_length, expected, sizeof(expected));

  SendMethod(messenger, codec, "pickJson", pick);
  GtkFileChooserNative* second = last_chooser;
  SelectFile(second, file);
  g_signal_emit_by_name(second, "response", GTK_RESPONSE_ACCEPT);
  g_assert_null(messenger->response);
  WorkspaceFileChannelDestroy(channel);  // Do not wait for the worker.
  AssertResponseError(messenger, codec, "unavailable");
  channel = WorkspaceFileChannelCreateForMessenger(
      FL_BINARY_MESSENGER(messenger), GTK_WINDOW(window), CaptureChooser);
  SendMethod(messenger, codec, "pickJson", pick);
  GtkFileChooserNative* third = last_chooser;
  const unsigned closed_responses = messenger->responses;
  const gint64 deadline = g_get_monotonic_time() + G_TIME_SPAN_SECOND / 4;
  while (g_get_monotonic_time() < deadline) {
    while (g_main_context_iteration(nullptr, FALSE)) {}
    g_usleep(1000);
  }
  g_assert_cmpuint(messenger->responses, ==, closed_responses);
  g_assert_null(messenger->response);  // Old completion cannot finish new call.
  g_signal_emit_by_name(third, "response", GTK_RESPONSE_CANCEL);
  WorkspaceFileChannelDestroy(channel);
  g_object_unref(first);
  g_object_unref(save_chooser);
  g_object_unref(second);
  g_object_unref(third);
  gtk_widget_destroy(window);
  g_object_unref(messenger);
  g_assert_true(g_file_delete(file, nullptr, nullptr));
  g_assert_cmpint(g_rmdir(directory), ==, 0);
}

void TestProductionChooserCleanup() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  auto* messenger = reinterpret_cast<TestMessenger*>(
      g_object_new(test_messenger_get_type(), nullptr));
  auto* channel = WorkspaceFileChannelCreateForMessenger(
      FL_BINARY_MESSENGER(messenger), GTK_WINDOW(window));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlValue) pick = MakePickArguments(524288);
  SendMethod(messenger, codec, "pickJson", pick);
  WorkspaceFileChannelDestroy(channel);
  AssertResponseError(messenger, codec, "unavailable");
  gtk_widget_destroy(window);
  g_object_unref(messenger);
}

}  // namespace

int main(int argc, char** argv) {
  g_setenv("GSETTINGS_BACKEND", "memory", TRUE);
  gtk_init(&argc, &argv);
  g_test_init(&argc, &argv, nullptr);
  g_test_add_func("/workspace/filename", TestFilenameContract);
  g_test_add_func("/workspace/arguments", TestArgumentContract);
  g_test_add_func("/workspace/bounded_io", TestBoundedIo);
  g_test_add_func("/workspace/method_channel", TestMethodChannelContract);
  g_test_add_func("/workspace/dialog_lifecycle", TestDialogLifecycle);
  g_test_add_func("/workspace/async_io_lifecycle", TestAsyncIoLifecycle);
  g_test_add_func("/workspace/production_chooser_cleanup", TestProductionChooserCleanup);
  return g_test_run();
}
