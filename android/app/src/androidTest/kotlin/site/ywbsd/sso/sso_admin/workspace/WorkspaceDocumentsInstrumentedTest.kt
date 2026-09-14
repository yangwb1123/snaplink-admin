package site.ywbsd.sso.sso_admin.workspace

import android.app.Activity
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import io.flutter.plugin.common.FlutterException
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the real production channel, system picker, and Downloads document provider. */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 29)
class WorkspaceDocumentsInstrumentedTest {
    private val host = WorkspaceDocumentsTestSupport()

    @Before fun setUp() = host.start()
    @After fun tearDown() = host.stop()

    @Test fun capabilitiesAndInvalidArgumentsUseTheFlutterCodec() {
        assertEquals(mapOf("version" to 1, "pick" to true, "save" to true),
            host.invoke("capabilities").await())
        for (limit in listOf(0, 524289, 1.5, true)) {
            error("invalid_arguments", host.invoke("pickJson", mapOf("maxBytes" to limit)))
        }
        error("invalid_arguments", host.invoke("saveJson",
            mapOf("filename" to "workspace-a.json\n", "bytes" to byteArrayOf(1))))
        error("too_large", host.invoke("saveJson",
            mapOf("filename" to host.name(), "bytes" to ByteArray(524289))))
        assertEquals(-1, host.owner.lastRequestCode)
    }

    @Test fun pickCancellationAndBusyCompleteExactlyOnce() {
        val pending = host.invoke("pickJson", mapOf("maxBytes" to 524288))
        host.awaitPicker()
        error("busy", host.invoke("pickJson", mapOf("maxBytes" to 1)))
        error("busy", host.invoke("saveJson",
            mapOf("filename" to host.name(), "bytes" to byteArrayOf(1))))
        host.device.pressBack()
        assertNull(pending.await())
        assertEquals(1, pending.count.get())
    }

    @Test fun saveCancellationReturnsFalse() {
        val pending = host.invoke("saveJson",
            mapOf("filename" to host.name(), "bytes" to "cancel".toByteArray()))
        host.awaitPicker()
        host.device.pressBack()
        assertEquals(false, pending.await())
        assertEquals(1, pending.count.get())
    }

    @Test fun pickReadsExactBytesAtInclusiveLimit() {
        val name = host.name()
        val bytes = ByteArray(524288) { (it % 251).toByte() }
        host.fixture(name, bytes)
        val pending = host.invoke("pickJson", mapOf("maxBytes" to bytes.size))
        host.pick(name)
        assertArrayEquals(bytes, pending.await() as ByteArray)
        assertEquals(1, pending.count.get())
    }

    @Test fun providerDocumentOverLimitIsRejected() {
        val name = host.name()
        host.fixture(name, ByteArray(32769) { 65 })
        val pending = host.invoke("pickJson", mapOf("maxBytes" to 32768))
        host.pick(name)
        error("too_large", pending)
    }

    @Test fun saveAcknowledgesExactBytesAndAllowsUserRename() {
        val bytes = "{\"schema\":\"pbatch.workspace.v1\",\"message\":\"你好\",\"files\":[]}".toByteArray()
        val renamed = "renamed-${System.nanoTime()}.json"
        val pending = host.invoke("saveJson",
            mapOf("filename" to host.name(), "bytes" to bytes))
        host.save(renamed)
        assertEquals(true, pending.await())
        val uri = host.selected()
        assertArrayEquals(bytes, host.read(uri))
        host.resolver.query(uri, arrayOf("_display_name"), null, null, null)!!.use {
            assertTrue(it.moveToFirst())
            assertEquals(renamed, it.getString(0))
        }
    }

    @Test fun duplicateNamePreservesExistingDocumentAndSavesExactNewBytes() {
        val name = host.name()
        val original = ByteArray(8192) { 88 }
        val existing = host.fixture(name, original)
        val bytes = "{\"files\":[]}".toByteArray()
        val pending = host.invoke("saveJson", mapOf("filename" to name, "bytes" to bytes))
        host.save()
        assertEquals(true, pending.await())
        assertArrayEquals(bytes, host.read(host.selected()))
        assertArrayEquals(original, host.read(existing))
    }

    @Test fun existingProviderDescriptorIsTruncatedBeforeAcknowledgement() {
        val uri = host.fixture(host.name(), ByteArray(8192) { 88 })
        val bytes = "{\"files\":[]}".toByteArray()
        val pending = host.invoke("saveJson",
            mapOf("filename" to host.name(), "bytes" to bytes))
        host.awaitPicker()
        // Downloads' CREATE_DOCUMENT allocates a new file for duplicate names.
        // Inject an existing provider URI to cover the separate descriptor mode contract.
        host.instrumentation.runOnMainSync {
            assertTrue(host.owner.files.onActivityResult(host.owner.lastRequestCode,
                Activity.RESULT_OK, Intent().setData(uri)))
        }
        assertEquals(true, pending.await())
        assertArrayEquals(bytes, host.read(uri))
        host.device.pressBack()
        host.instrumentation.waitForIdleSync()
        assertEquals(1, pending.count.get())
    }

    @Test fun closedOwnerAndStaleCallbacksCannotCompleteTheNextRequest() {
        val old = host.invoke("pickJson", mapOf("maxBytes" to 1024))
        host.awaitPicker()
        val oldCode = host.owner.lastRequestCode
        host.instrumentation.runOnMainSync { host.owner.replaceChannel() }
        error("unavailable", old)
        host.device.pressBack()
        host.instrumentation.waitForIdleSync()
        val next = host.invoke("pickJson", mapOf("maxBytes" to 1024))
        host.awaitPicker()
        assertNotEquals(oldCode, host.owner.lastRequestCode)
        host.instrumentation.runOnMainSync {
            assertFalse(host.owner.files.onActivityResult(oldCode, Activity.RESULT_OK, Intent()))
        }
        assertTrue(next.isPending())
        host.device.pressBack()
        assertNull(next.await())
        assertEquals(1, old.count.get())
        assertEquals(1, next.count.get())
    }

    private fun error(code: String, reply: WorkspaceTestReply) {
        try {
            reply.await()
            fail("Expected native error $code")
        } catch (failure: FlutterException) {
            assertEquals(code, failure.code)
            assertNull(failure.details)
            assertFalse(failure.message.orEmpty().contains("content://"))
        }
        assertEquals(1, reply.count.get())
    }
}
