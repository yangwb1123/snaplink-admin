#include "workspace_file_contract.h"

namespace workspace_files {
namespace {

const flutter::EncodableValue* Field(const flutter::EncodableMap& arguments,
                                    const char* name) {
  const auto value = arguments.find(flutter::EncodableValue(name));
  return value == arguments.end() ? nullptr : &value->second;
}

}  // namespace

bool IsSafeFilename(const std::string& filename) {
  constexpr size_t prefix = 10;
  constexpr size_t suffix = 5;
  if (filename.size() < prefix + 1 + suffix ||
      filename.size() > prefix + 96 + suffix ||
      filename.compare(0, prefix, "workspace-") != 0 ||
      filename.compare(filename.size() - suffix, suffix, ".json") != 0) {
    return false;
  }
  for (size_t index = prefix; index < filename.size() - suffix; ++index) {
    const char character = filename[index];
    if (!((character >= 'A' && character <= 'Z') ||
          (character >= 'a' && character <= 'z') ||
          (character >= '0' && character <= '9') ||
          character == '_' || character == '-')) return false;
  }
  return true;
}

ArgumentStatus ParsePick(const flutter::EncodableValue* arguments,
                         size_t* maximum) {
  const auto* map = arguments == nullptr ? nullptr :
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr || map->size() != 1 || maximum == nullptr) {
    return ArgumentStatus::kInvalid;
  }
  const auto* value = Field(*map, "maxBytes");
  if (value == nullptr) return ArgumentStatus::kInvalid;
  int64_t limit = 0;
  if (const auto* narrow = std::get_if<int32_t>(value)) limit = *narrow;
  else if (const auto* wide = std::get_if<int64_t>(value)) limit = *wide;
  else return ArgumentStatus::kInvalid;
  if (limit < 1 || limit > static_cast<int64_t>(kMaxBytes)) {
    return ArgumentStatus::kInvalid;
  }
  *maximum = static_cast<size_t>(limit);
  return ArgumentStatus::kOk;
}

ArgumentStatus ParseSave(const flutter::EncodableValue* arguments,
                         SaveRequest* request) {
  const auto* map = arguments == nullptr ? nullptr :
      std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr || map->size() != 2 || request == nullptr) {
    return ArgumentStatus::kInvalid;
  }
  const auto* name_value = Field(*map, "filename");
  const auto* byte_value = Field(*map, "bytes");
  const auto* name = name_value == nullptr ? nullptr :
      std::get_if<std::string>(name_value);
  const auto* bytes = byte_value == nullptr ? nullptr :
      std::get_if<std::vector<uint8_t>>(byte_value);
  if (name == nullptr || bytes == nullptr || !IsSafeFilename(*name)) {
    return ArgumentStatus::kInvalid;
  }
  if (bytes->size() > kMaxBytes) return ArgumentStatus::kTooLarge;
  request->filename = *name;
  request->bytes = *bytes;
  return ArgumentStatus::kOk;
}

}  // namespace workspace_files
