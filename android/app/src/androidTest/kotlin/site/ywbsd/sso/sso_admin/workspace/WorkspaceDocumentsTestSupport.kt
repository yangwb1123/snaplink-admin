package site.ywbsd.sso.sso_admin.workspace

import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.DocumentsContract
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiSelector
import androidx.test.uiautomator.Until
import org.junit.Assert.assertNotNull
import java.util.UUID

/** Files and UI belong only to the explicitly selected disposable test emulator. */
class WorkspaceDocumentsTestSupport {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val device: UiDevice = UiDevice.getInstance(instrumentation)
    val resolver = instrumentation.targetContext.contentResolver
    val documents = mutableSetOf<Uri>()
    lateinit var scenario: ActivityScenario<WorkspaceFilesTestActivity>
    lateinit var owner: WorkspaceFilesTestActivity

    fun start() {
        device.wakeUp()
        scenario = ActivityScenario.launch(WorkspaceFilesTestActivity::class.java)
        scenario.onActivity { owner = it }
    }

    fun stop() {
        try {
            documents.forEach {
                if (DocumentsContract.isDocumentUri(instrumentation.targetContext, it)) {
                    DocumentsContract.deleteDocument(resolver, it)
                } else {
                    resolver.delete(it, null, null)
                }
            }
        } finally {
            scenario.close()
        }
    }

    fun invoke(method: String, args: Any? = null): WorkspaceTestReply {
        lateinit var reply: WorkspaceTestReply
        instrumentation.runOnMainSync { reply = owner.messenger.invoke(method, args) }
        return reply
    }

    fun name(): String = "workspace-${UUID.randomUUID()}.json"

    fun fixture(filename: String, bytes: ByteArray): Uri {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, filename)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri = checkNotNull(resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values))
        documents.add(uri)
        resolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
        return uri
    }

    fun awaitPicker() {
        check(device.wait(Until.hasObject(By.pkg("com.google.android.documentsui")), 10000) ||
            device.wait(Until.hasObject(By.pkg("com.android.documentsui")), 10000)) {
            "System DocumentsUI did not open"
        }
    }

    fun downloads() {
        awaitPicker()
        val roots = device.wait(Until.findObject(By.desc("Show roots")), 5000)
        checkNotNull(roots) { "DocumentsUI roots button missing" }.click()
        device.waitForIdle()
        // Resolve the ListView row at click time; DocumentsUI recycles its text nodes.
        val downloads = device.findObject(UiSelector().resourceId("android:id/title").text("Downloads"))
        check(downloads.waitForExists(5000)) { "Downloads provider missing" }
        downloads.click()
        device.waitForIdle()
    }

    fun pick(filename: String) {
        downloads()
        val document = device.findObject(UiSelector().text(filename))
        check(document.waitForExists(5000)) { "Seeded workspace document missing" }
        document.click()
    }

    fun save(filename: String? = null) {
        downloads()
        if (filename != null) {
            checkNotNull(device.wait(Until.findObject(By.clazz("android.widget.EditText")), 5000))
                .text = filename
        }
        checkNotNull(device.wait(Until.findObject(By.text("SAVE")), 5000)).click()
    }

    fun selected(): Uri {
        instrumentation.waitForIdleSync()
        assertNotNull("Activity did not receive selected document URI", owner.lastDocument)
        return owner.lastDocument!!.also { documents.add(it) }
    }

    fun read(uri: Uri): ByteArray = resolver.openInputStream(uri)!!.use { it.readBytes() }
}
