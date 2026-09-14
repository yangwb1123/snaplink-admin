package site.ywbsd.sso.sso_admin.workspace

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.atomic.AtomicInteger

internal const val MAX_WORKSPACE_BYTES = 524288

/** Public errors intentionally contain no document names, paths, URIs, or content. */
internal class WorkspaceFileFailure(val code: String) : Exception(
    when (code) {
        "invalid_arguments" -> "Invalid workspace file arguments."
        "too_large" -> "Workspace file exceeds the size limit."
        "busy" -> "A workspace file operation is already active."
        "unavailable" -> "Workspace file operation is unavailable."
        else -> "Workspace file operation failed."
    },
)

internal data class WorkspaceSaveRequest(val filename: String, val bytes: ByteArray)

internal object WorkspaceFilePolicy {
    private val filenamePattern = Regex("^workspace-[A-Za-z0-9_-]{1,96}\\.json$")

    fun pickLimit(arguments: Any?): Int {
        val args = fields(arguments, setOf("maxBytes"))
        val limit = when (val value = args["maxBytes"]) {
            is Int -> value.toLong()
            is Long -> value
            else -> throw WorkspaceFileFailure("invalid_arguments")
        }
        if (limit !in 1L..MAX_WORKSPACE_BYTES.toLong()) {
            throw WorkspaceFileFailure("invalid_arguments")
        }
        return limit.toInt()
    }

    fun saveRequest(arguments: Any?): WorkspaceSaveRequest {
        val args = fields(arguments, setOf("filename", "bytes"))
        val filename = args["filename"] as? String
            ?: throw WorkspaceFileFailure("invalid_arguments")
        if (!filenamePattern.matches(filename)) {
            throw WorkspaceFileFailure("invalid_arguments")
        }
        val bytes = args["bytes"] as? ByteArray
            ?: throw WorkspaceFileFailure("invalid_arguments")
        if (bytes.size > MAX_WORKSPACE_BYTES) throw WorkspaceFileFailure("too_large")
        return WorkspaceSaveRequest(filename, bytes.copyOf())
    }

    private fun fields(arguments: Any?, expected: Set<String>): Map<*, *> {
        val args = arguments as? Map<*, *> ?: throw WorkspaceFileFailure("invalid_arguments")
        if (args.keys != expected) throw WorkspaceFileFailure("invalid_arguments")
        return args
    }

    /** Never requests or retains more than limit + 1 bytes from the provider. */
    fun readBounded(input: InputStream, limit: Int, cancelled: () -> Boolean): ByteArray {
        if (limit !in 1..MAX_WORKSPACE_BYTES) throw WorkspaceFileFailure("invalid_arguments")
        val output = ByteArrayOutputStream(minOf(limit, 8192))
        val buffer = ByteArray(minOf(limit + 1, 8192))
        while (output.size() <= limit) {
            checkCancelled(cancelled)
            val count = input.read(buffer, 0, minOf(buffer.size, limit + 1 - output.size()))
            if (count < 0) break
            if (count == 0) {
                val byte = input.read()
                if (byte < 0) break
                output.write(byte)
            } else {
                output.write(buffer, 0, count)
            }
        }
        checkCancelled(cancelled)
        if (output.size() > limit) throw WorkspaceFileFailure("too_large")
        return output.toByteArray()
    }

    fun writeBounded(output: OutputStream, bytes: ByteArray, cancelled: () -> Boolean) {
        if (bytes.size > MAX_WORKSPACE_BYTES) throw WorkspaceFileFailure("too_large")
        var offset = 0
        while (offset < bytes.size) {
            checkCancelled(cancelled)
            val count = minOf(8192, bytes.size - offset)
            output.write(bytes, offset, count)
            offset += count
        }
        checkCancelled(cancelled)
        output.flush()
        checkCancelled(cancelled)
    }

    private fun checkCancelled(cancelled: () -> Boolean) {
        if (cancelled()) throw WorkspaceFileFailure("unavailable")
    }
}

/** Main-thread request ownership; process-unique codes reject old Activity callbacks. */
internal class WorkspaceRequestState {
    private var current: Int? = null
    private var closed = false

    fun begin(): Int {
        if (closed) throw WorkspaceFileFailure("unavailable")
        if (current != null) throw WorkspaceFileFailure("busy")
        val token = nextCode.getAndIncrement()
        if (token !in 0..65535) throw WorkspaceFileFailure("unavailable")
        current = token
        return token
    }

    fun owns(token: Int): Boolean = !closed && current == token

    fun finish(token: Int): Boolean {
        if (!owns(token)) return false
        current = null
        return true
    }

    fun close() {
        closed = true
        current = null
    }

    companion object {
        private val nextCode = AtomicInteger(0x5200)
    }
}
