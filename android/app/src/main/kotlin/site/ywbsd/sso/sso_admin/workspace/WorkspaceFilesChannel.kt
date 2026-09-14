package site.ywbsd.sso.sso_admin.workspace

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean

/** User-selected documents only. The channel never accepts a filesystem path or URI. */
class WorkspaceFilesChannel(activity: Activity, messenger: BinaryMessenger) : Closeable {
    private var activity: Activity? = activity
    private val resolver = activity.applicationContext.contentResolver
    private val channel = MethodChannel(messenger, "site.ywbsd.sso/agent_workspace_files")
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val state = WorkspaceRequestState()
    private var pending: Pending? = null

    init {
        channel.setMethodCallHandler(::handleMethod)
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "capabilities" -> result.success(mapOf("version" to 1, "pick" to true, "save" to true))
                "pickJson" -> launch(result, WorkspaceFilePolicy.pickLimit(call.arguments), null)
                "saveJson" -> launch(result, null, WorkspaceFilePolicy.saveRequest(call.arguments))
                else -> result.notImplemented()
            }
        } catch (error: WorkspaceFileFailure) {
            result.error(error.code, error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    private fun launch(result: MethodChannel.Result, limit: Int?, save: WorkspaceSaveRequest?) {
        val owner = activity ?: throw WorkspaceFileFailure("unavailable")
        if (owner.isFinishing || owner.isDestroyed) throw WorkspaceFileFailure("unavailable")
        val operation = Pending(state.begin(), result, limit, save)
        pending = operation
        val intent = Intent(if (save == null) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/json")
        if (save != null) intent.putExtra(Intent.EXTRA_TITLE, save.filename)
        try {
            owner.startActivityForResult(intent, operation.code)
        } catch (_: ActivityNotFoundException) {
            finish(operation, failure = WorkspaceFileFailure("unavailable"))
        } catch (_: Exception) {
            finish(operation, failure = WorkspaceFileFailure("io_error"))
        }
    }

    /** Returns false for other plugins' request codes. Duplicate callbacks are consumed. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val operation = pending ?: return false
        if (operation.code != requestCode) return false
        if (!operation.awaitingPicker) return true
        operation.awaitingPicker = false
        if (resultCode == Activity.RESULT_CANCELED) {
            finish(operation, value = if (operation.save == null) null else false)
            return true
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || uri.scheme != ContentResolver.SCHEME_CONTENT) {
            finish(operation, failure = WorkspaceFileFailure("io_error"))
            return true
        }
        operation.future = worker.submit {
            try {
                val value = transfer(operation, uri)
                handler.post { finish(operation, value = value) }
            } catch (error: WorkspaceFileFailure) {
                handler.post { finish(operation, failure = error) }
            } catch (_: Exception) {
                handler.post { finish(operation, failure = WorkspaceFileFailure("io_error")) }
            }
        }
        return true
    }

    private fun transfer(operation: Pending, uri: Uri): Any {
        val save = operation.save
        val mode = if (save == null) "r" else "wt"
        val descriptor = resolver.openFileDescriptor(uri, mode, operation.signal)
            ?: throw WorkspaceFileFailure("io_error")
        return descriptor.use {
            val stream: Closeable = if (save == null) ParcelFileDescriptor.AutoCloseInputStream(descriptor)
                else ParcelFileDescriptor.AutoCloseOutputStream(descriptor)
            operation.track(stream)
            try {
                stream.use {
                    if (save == null) {
                        WorkspaceFilePolicy.readBounded(
                            it as ParcelFileDescriptor.AutoCloseInputStream,
                            operation.limit!!,
                            operation.cancelled::get,
                        )
                    } else {
                        WorkspaceFilePolicy.writeBounded(
                            it as ParcelFileDescriptor.AutoCloseOutputStream,
                            save.bytes,
                            operation.cancelled::get,
                        )
                        true
                    }
                }
            } finally {
                operation.release(stream)
            }
        }
    }

    private fun finish(operation: Pending, value: Any? = null, failure: WorkspaceFileFailure? = null) {
        if (!state.finish(operation.code)) return
        pending = null
        if (failure == null) operation.result.success(value)
        else operation.result.error(failure.code, failure.message, null)
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        val operation = pending
        state.close()
        pending = null
        activity = null
        if (operation != null) {
            operation.cancel()
            operation.result.error("unavailable", "Workspace file operation is unavailable.", null)
        }
        worker.shutdownNow()
    }

    private class Pending(
        val code: Int,
        val result: MethodChannel.Result,
        val limit: Int?,
        val save: WorkspaceSaveRequest?,
    ) {
        var awaitingPicker = true
        val cancelled = AtomicBoolean(false)
        val signal = CancellationSignal()
        var future: Future<*>? = null
        private var stream: Closeable? = null

        @Synchronized
        fun track(opened: Closeable) {
            if (cancelled.get()) {
                opened.close()
                throw WorkspaceFileFailure("unavailable")
            }
            stream = opened
        }

        @Synchronized
        fun release(opened: Closeable) {
            if (stream === opened) stream = null
        }

        fun cancel() {
            cancelled.set(true)
            future?.cancel(true)
            try {
                signal.cancel()
            } catch (_: Exception) {
                // A provider cancellation failure must not retain the local descriptor.
            }
            val opened = synchronized(this) { stream.also { stream = null } }
            try {
                opened?.close()
            } catch (_: Exception) {
                // The caller receives the fixed unavailable response; no provider details escape.
            }
        }
    }
}
