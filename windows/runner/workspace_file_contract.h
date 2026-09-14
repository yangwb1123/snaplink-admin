#ifndef RUNNER_WORKSPACE_FILE_CONTRACT_H_
#define RUNNER_WORKSPACE_FILE_CONTRACT_H_

#include <flutter/encodable_value.h>

namespace workspace_files {

constexpr size_t kMaxBytes = 512 * 1024;
enum class ArgumentStatus { kOk, kInvalid, kTooLarge };

struct SaveRequest {
  std::string filename;
  std::vector<uint8_t> bytes;
};

bool IsSafeFilename(const std::string& filename);
ArgumentStatus ParsePick(const flutter::EncodableValue* arguments,
                         size_t* maximum);
ArgumentStatus ParseSave(const flutter::EncodableValue* arguments,
                         SaveRequest* request);

}  // namespace workspace_files

#endif  // RUNNER_WORKSPACE_FILE_CONTRACT_H_
