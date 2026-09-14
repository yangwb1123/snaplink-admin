#include "workspace_file_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <objbase.h>

#include <cstdlib>
#include <iostream>
#include <utility>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
constexpr char kChannel[] = "site.ywbsd.sso/agent_workspace_files";

void Check(bool condition) {
  if (!condition) {
    std::cerr << "Workspace native channel assertion failed\n";
    std::exit(EXIT_FAILURE);
  }
}

struct Response {
  int replies = 0;
  bool success = false;
  bool unimplemented = false;
  EncodableValue value;
  std::string error;
  std::string message;
};

class Messenger : public flutter::BinaryMessenger {
 public:
  flutter::BinaryMessageHandler handler;

  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply = nullptr) const override {
    Check(false);  // This host only responds to incoming method calls.
  }

  void SetMessageHandler(const std::string& name,
                         flutter::BinaryMessageHandler callback) override {
    Check(name == kChannel);
    handler = std::move(callback);
  }

  Response Call(const std::string& method,
                EncodableValue arguments = EncodableValue()) {
    Check(static_cast<bool>(handler));
    const auto& codec = flutter::StandardMethodCodec::GetInstance();
    const auto encoded = codec.EncodeMethodCall(flutter::MethodCall<EncodableValue>(
        method, std::make_unique<EncodableValue>(std::move(arguments))));
    Response response;
    auto callback = handler;  // Allow the host to unregister during a reply.
    callback(encoded->data(), encoded->size(), [&](const uint8_t* bytes, size_t size) {
      ++response.replies;
      if (size == 0) {
        response.unimplemented = true;
        return;
      }
      flutter::MethodResultFunctions<EncodableValue> result(
          [&](const EncodableValue* value) {
            response.success = true;
            if (value != nullptr) response.value = *value;
          },
          [&](const std::string& code, const std::string& message,
              const EncodableValue* details) {
            response.error = code;
            response.message = message;
            Check(details == nullptr || details->IsNull());
          },
          [&]() { response.unimplemented = true; });
      Check(codec.DecodeAndProcessResponseEnvelope(bytes, size, &result));
    });
    Check(response.replies == 1);
    return response;
  }
};

EncodableValue Pick(EncodableValue limit) {
  return EncodableValue(EncodableMap{{EncodableValue("maxBytes"), std::move(limit)}});
}

void CheckError(const Response& response, const std::string& error,
                const std::string& message) {
  Check(!response.success && !response.unimplemented);
  Check(response.error == error && response.message == message);
}

}  // namespace

void TestWindowsChannel() {
  Messenger messenger;
  auto channel = std::make_unique<workspace_files::FileChannel>(&messenger, nullptr);
  const auto capabilities = messenger.Call("capabilities");
  const EncodableValue expected(EncodableMap{
      {EncodableValue("version"), EncodableValue(int32_t{1})},
      {EncodableValue("pick"), EncodableValue(true)},
      {EncodableValue("save"), EncodableValue(true)}});
  Check(capabilities.success && capabilities.value == expected);
  Check(messenger.Call("unknownMethod").unimplemented);
  CheckError(messenger.Call("pickJson", Pick(EncodableValue(true))),
             "invalid_arguments", "Invalid workspace file arguments");
  CheckError(messenger.Call("saveJson", EncodableValue(EncodableMap{
      {EncodableValue("filename"), EncodableValue("workspace-a.json")},
      {EncodableValue("bytes"), EncodableValue(std::vector<uint8_t>(524289, 1))}})),
      "too_large", "Invalid workspace file arguments");

  // No COM apartment is initialized by this executable. Exercise the real
  // CoCreateInstance failure without showing a dialog or requiring a desktop.
  APTTYPE apartment;
  APTTYPEQUALIFIER qualifier;
  Check(CoGetApartmentType(&apartment, &qualifier) == CO_E_NOTINITIALIZED);
  for (int attempt = 0; attempt < 2; ++attempt) {
    CheckError(messenger.Call("pickJson", Pick(EncodableValue(int32_t{16}))),
               "unavailable", "Workspace file operation failed");
  }
  const UINT completion = RegisterWindowMessageW(
      L"site.ywbsd.sso.agent_workspace_files.complete.v1");
  Check(completion != 0 && channel->HandleWindowMessage(completion));
  Check(!channel->HandleWindowMessage(WM_APP));
  channel.reset();
  Check(!messenger.handler);
  std::cout << "Workspace Windows standard codec/channel tests passed\n";
}
