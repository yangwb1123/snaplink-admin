#ifndef RUNNER_WORKSPACE_FILE_CONTRACT_LINUX_H_
#define RUNNER_WORKSPACE_FILE_CONTRACT_LINUX_H_

#include <flutter_linux/flutter_linux.h>

#include <cstdint>

constexpr uint32_t kWorkspaceFileMaxBytes = 512 * 1024;

enum class WorkspaceArgumentStatus {
  kOk,
  kInvalidArguments,
  kTooLarge,
};

struct WorkspaceSaveRequest {
  const gchar* filename;
  const uint8_t* bytes;
  size_t length;
};

WorkspaceArgumentStatus ParseWorkspacePickArguments(FlValue* arguments,
                                                     uint32_t* max_bytes);
WorkspaceArgumentStatus ParseWorkspaceSaveArguments(
    FlValue* arguments, WorkspaceSaveRequest* request);
bool IsSafeWorkspaceFilename(const gchar* filename);

#endif  // RUNNER_WORKSPACE_FILE_CONTRACT_LINUX_H_
