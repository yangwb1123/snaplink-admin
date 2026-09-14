package site.ywbsd.sso.sso_admin

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import site.ywbsd.sso.sso_admin.workspace.WorkspaceFilesChannel

class MainActivity : FlutterActivity() {
    private var workspaceFiles: WorkspaceFilesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        workspaceFiles?.close()
        workspaceFiles = WorkspaceFilesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (workspaceFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        workspaceFiles?.close()
        workspaceFiles = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        workspaceFiles?.close()
        workspaceFiles = null
        super.onDestroy()
    }
}
