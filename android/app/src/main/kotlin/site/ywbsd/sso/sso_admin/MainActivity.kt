package site.ywbsd.sso.sso_admin

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import site.ywbsd.sso.sso_admin.workspace.WorkspaceFilesChannel

class MainActivity : FlutterActivity() {
    private var workspaceFiles: WorkspaceFilesChannel? = null
    private var forgeInstrumentation: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        workspaceFiles?.close()
        workspaceFiles = WorkspaceFilesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            forgeInstrumentation?.setMethodCallHandler(null)
            forgeInstrumentation = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                FORGE_INSTRUMENTATION_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    val preferences = getSharedPreferences(
                        FORGE_INSTRUMENTATION_PREFERENCES,
                        Context.MODE_PRIVATE,
                    )
                    if (call.method == "configuration") {
                        val apiURL = preferences.getString(FORGE_COORDINATOR_API_URL, null)
                        val conversationID = preferences.getString(FORGE_COORDINATOR_CONVERSATION_ID, null)
                        val clientInstanceID = preferences.getString(FORGE_COORDINATOR_CLIENT_INSTANCE_ID, null)
                        val sessionView = preferences.getString(FORGE_COORDINATOR_SESSION_VIEW, null)
                        val resourceView = preferences.getString(FORGE_COORDINATOR_RESOURCE_VIEW, null)
                        val prompt = preferences.getString(FORGE_COORDINATOR_PROMPT, null)
                        val idempotencyKey = preferences.getString(FORGE_COORDINATOR_IDEMPOTENCY_KEY, null)
                        if (apiURL == null || conversationID == null || clientInstanceID == null ||
                            sessionView == null || resourceView == null || prompt == null || idempotencyKey == null) {
                            result.error("missing_configuration", "Coordinator probe configuration is missing.", null)
                            return@setMethodCallHandler
                        }
                        result.success(
                            mapOf(
                                "api_url" to apiURL,
                                "conversation_id" to conversationID,
                                "client_instance_id" to clientInstanceID,
                                "session_view" to sessionView,
                                "resource_view" to resourceView,
                                "expected_version" to preferences.getLong(FORGE_COORDINATOR_EXPECTED_VERSION, 0L),
                                "after_cursor" to preferences.getLong(FORGE_COORDINATOR_AFTER_CURSOR, 0L),
                                "prompt" to prompt,
                                "idempotency_key" to idempotencyKey,
                                "run_index" to preferences.getInt(FORGE_COORDINATOR_RUN_INDEX, 1),
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    if (call.method == "complete") {
                        val ok = call.argument<Boolean>("ok")
                        if (ok == null) {
                            result.error("invalid_arguments", "Missing coordinator completion status.", null)
                            return@setMethodCallHandler
                        }
                        val count = preferences.getInt(FORGE_COORDINATOR_COMPLETION_COUNT, 0)
                        preferences.edit()
                            .putInt(FORGE_COORDINATOR_COMPLETION_COUNT, count + 1)
                            .putBoolean(FORGE_COORDINATOR_LAST_OK, ok)
                            .putString(FORGE_COORDINATOR_LAST_REPORT, call.argument<String>("report"))
                            .putString(FORGE_COORDINATOR_LAST_ERROR, call.argument<String>("error"))
                            .apply()
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    if (call.method != "request") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    val path = call.argument<String>("path")
                    val authorized = call.argument<Boolean>("authorized")
                    if (path == null || authorized == null) {
                        result.error("invalid_arguments", "Missing instrumentation request fields.", null)
                        return@setMethodCallHandler
                    }
                    val count = preferences.getInt(FORGE_INSTRUMENTATION_REQUEST_COUNT, 0)
                    val paths = preferences.getString(FORGE_INSTRUMENTATION_REQUEST_PATHS, "")
                        .orEmpty()
                    val updatedPaths = if (paths.isEmpty()) path else "$paths\n$path"
                    preferences.edit()
                        .putInt(FORGE_INSTRUMENTATION_REQUEST_COUNT, count + 1)
                        .putString(FORGE_INSTRUMENTATION_LAST_PATH, path)
                        .putString(FORGE_INSTRUMENTATION_REQUEST_PATHS, updatedPaths.takeLast(64 * 1024))
                        .putBoolean(FORGE_INSTRUMENTATION_LAST_AUTHORIZED, authorized)
                        .apply()
                    result.success(null)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (workspaceFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        workspaceFiles?.close()
        workspaceFiles = null
        forgeInstrumentation?.setMethodCallHandler(null)
        forgeInstrumentation = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        workspaceFiles?.close()
        workspaceFiles = null
        forgeInstrumentation?.setMethodCallHandler(null)
        forgeInstrumentation = null
        super.onDestroy()
    }

    internal companion object {
        const val FORGE_INSTRUMENTATION_CHANNEL = "site.ywbsd.sso/forge_instrumentation"
        const val FORGE_INSTRUMENTATION_PREFERENCES = "forge_instrumentation"
        const val FORGE_INSTRUMENTATION_REQUEST_COUNT = "request_count"
        const val FORGE_INSTRUMENTATION_LAST_PATH = "last_path"
        const val FORGE_INSTRUMENTATION_REQUEST_PATHS = "request_paths"
        const val FORGE_INSTRUMENTATION_LAST_AUTHORIZED = "last_authorized"
        const val FORGE_COORDINATOR_API_URL = "coordinator_api_url"
        const val FORGE_COORDINATOR_CONVERSATION_ID = "coordinator_conversation_id"
        const val FORGE_COORDINATOR_CLIENT_INSTANCE_ID = "coordinator_client_instance_id"
        const val FORGE_COORDINATOR_SESSION_VIEW = "coordinator_session_view"
        const val FORGE_COORDINATOR_RESOURCE_VIEW = "coordinator_resource_view"
        const val FORGE_COORDINATOR_EXPECTED_VERSION = "coordinator_expected_version"
        const val FORGE_COORDINATOR_AFTER_CURSOR = "coordinator_after_cursor"
        const val FORGE_COORDINATOR_PROMPT = "coordinator_prompt"
        const val FORGE_COORDINATOR_IDEMPOTENCY_KEY = "coordinator_idempotency_key"
        const val FORGE_COORDINATOR_RUN_INDEX = "coordinator_run_index"
        const val FORGE_COORDINATOR_COMPLETION_COUNT = "coordinator_completion_count"
        const val FORGE_COORDINATOR_LAST_OK = "coordinator_last_ok"
        const val FORGE_COORDINATOR_LAST_REPORT = "coordinator_last_report"
        const val FORGE_COORDINATOR_LAST_ERROR = "coordinator_last_error"
    }
}
