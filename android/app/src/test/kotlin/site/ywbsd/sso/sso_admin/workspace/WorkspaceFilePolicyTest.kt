package site.ywbsd.sso.sso_admin.workspace

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import org.junit.Assert.*
import org.junit.Test

class WorkspaceFilePolicyTest {
    @Test
    fun pickAcceptsOnlyBoundedIntegers() {
        assertEquals(1, WorkspaceFilePolicy.pickLimit(mapOf("maxBytes" to 1)))
        assertEquals(MAX_WORKSPACE_BYTES, WorkspaceFilePolicy.pickLimit(mapOf("maxBytes" to 524288L)))
        listOf(null, false, "12", 12.0, 0, -1, 524289, Long.MAX_VALUE).forEach {
            failure("invalid_arguments") { WorkspaceFilePolicy.pickLimit(mapOf("maxBytes" to it)) }
        }
    }

    @Test
    fun argumentMapsRejectMissingAndExtraFields() {
        listOf(null, emptyMap<String, Any>(), listOf(1), mapOf("maxBytes" to 1, "path" to "secret")).forEach {
            failure("invalid_arguments") { WorkspaceFilePolicy.pickLimit(it) }
        }
        listOf(null, emptyMap<String, Any>(), mapOf("filename" to "workspace-a.json"),
            mapOf("filename" to "workspace-a.json", "bytes" to byteArrayOf(), "path" to "secret"),
        ).forEach { failure("invalid_arguments") { WorkspaceFilePolicy.saveRequest(it) } }
    }

    @Test
    fun filenameMatchesExactPortableContract() {
        listOf("workspace-a.json", "workspace-A_9-z.json", "workspace-${"x".repeat(96)}.json").forEach {
            assertEquals(it, save(it).filename)
        }
        listOf("workspace-.json", "workspace-${"x".repeat(97)}.json", "Workspace-a.json",
            "workspace-a.JSON", "workspace-é.json", "../workspace-a.json", "workspace-a/b.json",
            "workspace-a\\b.json", "workspace-a.json\n", "workspace-a.json ", "workspace-a\u0000.json",
            "workspace-a:b.json", "CON.json", "workspace- a.json",
        ).forEach { failure("invalid_arguments") { save(it) } }
    }

    @Test
    fun saveRequiresTypedBoundedBytesAndSnapshotsOwnership() {
        failure("invalid_arguments") {
            WorkspaceFilePolicy.saveRequest(mapOf("filename" to "workspace-a.json", "bytes" to listOf(1)))
        }
        assertEquals(0, save("workspace-a.json").bytes.size)
        assertEquals(MAX_WORKSPACE_BYTES, save("workspace-a.json", ByteArray(MAX_WORKSPACE_BYTES)).bytes.size)
        failure("too_large") { save("workspace-a.json", ByteArray(MAX_WORKSPACE_BYTES + 1)) }
        val original = byteArrayOf(1, 2, 3)
        val copied = save("workspace-a.json", original).bytes
        original[0] = 9
        assertArrayEquals(byteArrayOf(1, 2, 3), copied)
    }

    @Test
    fun readAcceptsEmptyAndInclusiveLimitWithoutClosingCallerStream() {
        val stream = CountingInput(7)
        assertArrayEquals(ByteArray(7) { 42 }, WorkspaceFilePolicy.readBounded(stream, 7) { false })
        assertEquals(7, stream.consumed)
        assertFalse(stream.closed)
        assertEquals(0, WorkspaceFilePolicy.readBounded(ByteArrayInputStream(byteArrayOf()), 1) { false }.size)
    }

    @Test
    fun unknownLargeFileConsumesOnlyLimitPlusOneBytes() {
        listOf(1, 8191, 8192, MAX_WORKSPACE_BYTES).forEach { limit ->
            val stream = CountingInput(Int.MAX_VALUE)
            failure("too_large") { WorkspaceFilePolicy.readBounded(stream, limit) { false } }
            assertEquals(limit + 1, stream.consumed)
            assertTrue(stream.largestRequest <= 8192)
        }
    }

    @Test
    fun fragmentedReadsPreserveBytes() {
        val input = object : ByteArrayInputStream(byteArrayOf(0, -1, 65, 66)) {
            override fun read(bytes: ByteArray, offset: Int, length: Int): Int = super.read(bytes, offset, minOf(1, length))
        }
        assertArrayEquals(byteArrayOf(0, -1, 65, 66), WorkspaceFilePolicy.readBounded(input, 4) { false })
    }

    @Test
    fun zeroLengthProviderReadDoesNotSpinOrExceedBound() {
        val input = object : InputStream() {
            var consumed = 0
            override fun read(bytes: ByteArray, offset: Int, length: Int): Int = 0
            override fun read(): Int { consumed++; return 42 }
        }
        failure("too_large") { WorkspaceFilePolicy.readBounded(input, 3) { false } }
        assertEquals(4, input.consumed)
    }

    @Test
    fun invalidReadLimitNeverTouchesProvider() {
        listOf(0, -1, MAX_WORKSPACE_BYTES + 1).forEach { limit ->
            val input = CountingInput(12)
            failure("invalid_arguments") { WorkspaceFilePolicy.readBounded(input, limit) { false } }
            assertEquals(0, input.consumed)
        }
    }

    @Test
    fun cancelledReadStopsBeforeFirstOrNextChunk() {
        val before = CountingInput(12)
        failure("unavailable") { WorkspaceFilePolicy.readBounded(before, 12) { true } }
        assertEquals(0, before.consumed)
        val during = CountingInput(MAX_WORKSPACE_BYTES)
        failure("unavailable") { WorkspaceFilePolicy.readBounded(during, MAX_WORKSPACE_BYTES) { during.consumed > 0 } }
        assertEquals(8192, during.consumed)
    }

    @Test
    fun readIoFailuresCannotReturnPartialSuccess() {
        val input = object : InputStream() {
            override fun read(): Int = throw IOException("provider-private-details")
        }
        assertThrows(IOException::class.java) { WorkspaceFilePolicy.readBounded(input, 4) { false } }
    }

    @Test
    fun boundedWritesPreserveBytesAndFlushBeforeSuccess() {
        val output = RecordingOutput()
        val bytes = ByteArray(MAX_WORKSPACE_BYTES) { (it % 256).toByte() }
        WorkspaceFilePolicy.writeBounded(output, bytes) { false }
        assertArrayEquals(bytes, output.data.toByteArray())
        assertEquals(8192, output.largestWrite)
        assertTrue(output.flushed)
        assertFalse(output.closed)
        val empty = RecordingOutput()
        WorkspaceFilePolicy.writeBounded(empty, byteArrayOf()) { false }
        assertTrue(empty.flushed)
    }

    @Test
    fun tooLargeWriteTouchesNoProviderBytes() {
        val output = RecordingOutput()
        failure("too_large") { WorkspaceFilePolicy.writeBounded(output, ByteArray(MAX_WORKSPACE_BYTES + 1)) { false } }
        assertEquals(0, output.data.size())
        assertFalse(output.flushed)
    }

    @Test
    fun cancelledWriteStopsBeforeFlushAndBeforeNextChunk() {
        val output = RecordingOutput()
        failure("unavailable") { WorkspaceFilePolicy.writeBounded(output, ByteArray(16384)) { output.data.size() > 0 } }
        assertEquals(8192, output.data.size())
        assertFalse(output.flushed)
        val before = RecordingOutput()
        failure("unavailable") { WorkspaceFilePolicy.writeBounded(before, byteArrayOf(1)) { true } }
        assertEquals(0, before.data.size())
    }

    @Test
    fun writeAndFlushIoFailuresCannotReportSuccess() {
        val writeFailure = object : OutputStream() {
            override fun write(value: Int) { throw IOException("provider-private-details") }
        }
        assertThrows(IOException::class.java) { WorkspaceFilePolicy.writeBounded(writeFailure, byteArrayOf(1)) { false } }
        val flushFailure = object : ByteArrayOutputStream() {
            override fun flush() { throw IOException("provider-private-details") }
        }
        assertThrows(IOException::class.java) { WorkspaceFilePolicy.writeBounded(flushFailure, byteArrayOf(1)) { false } }
    }

    @Test
    fun errorMessagesAreFixedAndDoNotAcceptProviderDetails() {
        val errors = listOf("invalid_arguments", "too_large", "busy", "io_error", "unavailable")
        assertEquals(5, errors.map { WorkspaceFileFailure(it).message }.toSet().size)
        errors.forEach {
            assertFalse(WorkspaceFileFailure(it).message!!.contains("/"))
            assertNull(WorkspaceFileFailure(it).cause)
        }
    }

    private fun save(filename: String, bytes: ByteArray = byteArrayOf()) =
        WorkspaceFilePolicy.saveRequest(mapOf("filename" to filename, "bytes" to bytes))

    private fun failure(code: String, action: () -> Unit) {
        assertEquals(code, assertThrows(WorkspaceFileFailure::class.java, action).code)
    }

    private class CountingInput(private val availableBytes: Int) : InputStream() {
        var consumed = 0
        var largestRequest = 0
        var closed = false
        override fun read(): Int = if (consumed < availableBytes) { consumed++; 42 } else -1
        override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
            largestRequest = maxOf(largestRequest, length)
            if (consumed >= availableBytes) return -1
            val count = minOf(length, availableBytes - consumed)
            bytes.fill(42, offset, offset + count)
            consumed += count
            return count
        }
        override fun close() { closed = true }
    }

    private class RecordingOutput : OutputStream() {
        val data = ByteArrayOutputStream()
        var largestWrite = 0
        var flushed = false
        var closed = false
        override fun write(value: Int) { data.write(value) }
        override fun write(bytes: ByteArray, offset: Int, length: Int) {
            largestWrite = maxOf(largestWrite, length)
            data.write(bytes, offset, length)
        }
        override fun flush() { flushed = true }
        override fun close() { closed = true }
    }
}
