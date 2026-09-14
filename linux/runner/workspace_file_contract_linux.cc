#include "workspace_file_contract_linux.h"

#include <cstring>

namespace {

bool IsSafeFilenameCharacter(gchar character) {
  return (character >= 'A' && character <= 'Z') ||
         (character >= 'a' && character <= 'z') ||
         (character >= '0' && character <= '9') || character == '_' ||
         character == '-';
}

bool HasExactMapLength(FlValue* value, size_t length) {
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_MAP &&
         fl_value_get_length(value) == length;
}

}  // namespace

bool IsSafeWorkspaceFilename(const gchar* filename) {
  if (filename == nullptr) return false;
  const size_t length = std::strlen(filename);
  constexpr char kPrefix[] = "workspace-";
  constexpr char kSuffix[] = ".json";
  constexpr size_t kPrefixLength = sizeof(kPrefix) - 1;
  constexpr size_t kSuffixLength = sizeof(kSuffix) - 1;
  if (length < kPrefixLength + 1 + kSuffixLength ||
      length > kPrefixLength + 96 + kSuffixLength ||
      std::strncmp(filename, kPrefix, kPrefixLength) != 0 ||
      std::strcmp(filename + length - kSuffixLength, kSuffix) != 0) {
    return false;
  }
  for (size_t index = kPrefixLength; index < length - kSuffixLength; ++index) {
    if (!IsSafeFilenameCharacter(filename[index])) return false;
  }
  return true;
}

WorkspaceArgumentStatus ParseWorkspacePickArguments(FlValue* arguments,
                                                     uint32_t* max_bytes) {
  if (max_bytes == nullptr || !HasExactMapLength(arguments, 1)) {
    return WorkspaceArgumentStatus::kInvalidArguments;
  }
  FlValue* value = fl_value_lookup_string(arguments, "maxBytes");
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return WorkspaceArgumentStatus::kInvalidArguments;
  }
  const int64_t maximum = fl_value_get_int(value);
  if (maximum < 1 || maximum > kWorkspaceFileMaxBytes) {
    return WorkspaceArgumentStatus::kInvalidArguments;
  }
  *max_bytes = static_cast<uint32_t>(maximum);
  return WorkspaceArgumentStatus::kOk;
}

WorkspaceArgumentStatus ParseWorkspaceSaveArguments(
    FlValue* arguments, WorkspaceSaveRequest* request) {
  if (request == nullptr || !HasExactMapLength(arguments, 2)) {
    return WorkspaceArgumentStatus::kInvalidArguments;
  }
  FlValue* filename = fl_value_lookup_string(arguments, "filename");
  FlValue* bytes = fl_value_lookup_string(arguments, "bytes");
  if (filename == nullptr || fl_value_get_type(filename) != FL_VALUE_TYPE_STRING ||
      bytes == nullptr || fl_value_get_type(bytes) != FL_VALUE_TYPE_UINT8_LIST ||
      !IsSafeWorkspaceFilename(fl_value_get_string(filename))) {
    return WorkspaceArgumentStatus::kInvalidArguments;
  }
  const size_t length = fl_value_get_length(bytes);
  if (length > kWorkspaceFileMaxBytes) return WorkspaceArgumentStatus::kTooLarge;
  request->filename = fl_value_get_string(filename);
  request->bytes = fl_value_get_uint8_list(bytes);
  request->length = length;
  return WorkspaceArgumentStatus::kOk;
}
