#ifndef RUNNER_WORKSPACE_FILE_CHANNEL_LINUX_H_
#define RUNNER_WORKSPACE_FILE_CHANNEL_LINUX_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

struct WorkspaceFileChannel;
using WorkspaceFileChooserFactory = GtkFileChooserNative* (*)(
    GtkWindow* parent, gboolean save, const gchar* filename);

WorkspaceFileChannel* WorkspaceFileChannelCreate(FlEngine* engine,
                                                 GtkWindow* parent);
WorkspaceFileChannel* WorkspaceFileChannelCreateForMessenger(
    FlBinaryMessenger* messenger, GtkWindow* parent,
    WorkspaceFileChooserFactory factory = nullptr);
void WorkspaceFileChannelDestroy(WorkspaceFileChannel* channel);

#endif  // RUNNER_WORKSPACE_FILE_CHANNEL_LINUX_H_
