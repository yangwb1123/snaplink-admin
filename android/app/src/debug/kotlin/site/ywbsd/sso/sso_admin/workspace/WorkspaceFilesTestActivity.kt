package site.ywbsd.sso.sso_admin.workspace

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Debug-only owner for instrumentation. Uses the production channel and Flutter wire codec. */
class WorkspaceFilesTestActivity : Activity() {
    val messenger = WorkspaceTestMessenger()
    lateinit var files: WorkspaceFilesChannel
        private set
    var lastRequestCode = -1
        private set
    var lastDocument: Uri? = null
        private set

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply { text = "Workspace document instrumentation" })
        files = WorkspaceFilesChannel(this, messenger)
    }

    @Suppress("DEPRECATION")
    override fun startActivityForResult(intent: Intent, requestCode: Int) {
        lastRequestCode = requestCode
        lastDocument = null
        super.startActivityForResult(intent, requestCode)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        lastDocument = data?.data
        if (!files.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    fun replaceChannel() {
        files.close()
        files = WorkspaceFilesChannel(this, messenger)
    }

    override fun onDestroy() {
        files.close()
        super.onDestroy()
    }
}

/** Inbound codec adapter only: this does not mock the channel, Activity, picker, or provider. */
class WorkspaceTestMessenger : BinaryMessenger {
    private var handler: BinaryMessenger.BinaryMessageHandler? = null

    fun invoke(method: String, arguments: Any? = null): WorkspaceTestReply {
        val reply = WorkspaceTestReply()
        val request = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments))
        request.flip()
        checkNotNull(handler).onMessage(request, reply)
        return reply
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        check(channel == "site.ywbsd.sso/agent_workspace_files")
        this.handler = handler
    }

    override fun send(channel: String, message: ByteBuffer?) = error("Unexpected outbound message")
    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) =
        error("Unexpected outbound message")
}

class WorkspaceTestReply : BinaryMessenger.BinaryReply {
    private val done = CountDownLatch(1)
    private var envelope: ByteBuffer? = null
    val count = AtomicInteger()

    override fun reply(reply: ByteBuffer?) {
        count.incrementAndGet()
        envelope = reply?.apply { flip() }
        done.countDown()
    }

    fun await(): Any? {
        check(done.await(20, TimeUnit.SECONDS)) { "Native document response timed out" }
        return StandardMethodCodec.INSTANCE.decodeEnvelope(checkNotNull(envelope))
    }

    fun isPending(): Boolean = done.count != 0L
}
