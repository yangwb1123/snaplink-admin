#ifndef RUNNER_WORKSPACE_FILE_IO_LINUX_H_
#define RUNNER_WORKSPACE_FILE_IO_LINUX_H_

#include <gio/gio.h>

#include <cstddef>
#include <cstdint>

enum class WorkspaceFileIoStatus {
  kOk,
  kTooLarge,
  kIoError,
};

WorkspaceFileIoStatus ReadWorkspaceJson(GFile* file, size_t max_bytes,
                                        GBytes** result,
                                        GCancellable* cancellable = nullptr);
WorkspaceFileIoStatus SaveWorkspaceJson(GFile* file, const uint8_t* bytes,
                                        size_t length,
                                        GCancellable* cancellable = nullptr);

#endif  // RUNNER_WORKSPACE_FILE_IO_LINUX_H_
