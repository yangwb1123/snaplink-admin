#ifndef RUNNER_WORKSPACE_FILE_CHANNEL_H_
#define RUNNER_WORKSPACE_FILE_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

#include <memory>

namespace workspace_files {

struct ChannelState;

class FileChannel {
 public:
  FileChannel(flutter::BinaryMessenger* messenger, HWND parent);
  ~FileChannel();
  FileChannel(const FileChannel&) = delete;
  FileChannel& operator=(const FileChannel&) = delete;

  // Called only from the parent window's platform-thread message handler.
  bool HandleWindowMessage(UINT message);

 private:
  std::shared_ptr<ChannelState> state_;
};

}  // namespace workspace_files

#endif  // RUNNER_WORKSPACE_FILE_CHANNEL_H_
