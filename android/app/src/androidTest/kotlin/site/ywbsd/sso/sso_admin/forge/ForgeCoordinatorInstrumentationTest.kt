package site.ywbsd.sso.sso_admin.forge

import android.content.Context
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import site.ywbsd.sso.sso_admin.MainActivity

/**
 * Opt-in Android emulator journey against a caller-supplied Forge
 * Coordinator. The input file is copied into the app sandbox by the runner;
 * the bearer is written through the real Android secure-storage plugin and is
 * never passed as an instrumentation argument.
 *
 * This test is deliberately separate from the bounded fixture test. It may
 * only be selected by run_forge_shared_session_instrumentation.py with an
 * explicit emulator serial and an input file. It exercises Conversations,
 * Prompt idempotency, and the owner-local change cursor; it rejects every
 * device, Run-intent, placement, dispatch, and execution path.
 */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 23)
class ForgeCoordinatorInstrumentationTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val preferences = context.getSharedPreferences(
        "forge_instrumentation",
        Context.MODE_PRIVATE,
    )
    private val storage = FlutterSecureStorage(context)
    private val storageConfig = FlutterSecureStorageConfig(emptyMap())
    private var previousRecord: String? = null
    private var scenario: ActivityScenario<MainActivity>? = null
    private var inputFile: File? = null

    @Before
    fun setUp() {
        val name = InstrumentationRegistry.getArguments().getString(CONFIG_ARGUMENT)
        require(name != null && SAFE_NAME.matches(name)) {
            "The coordinator runner must provide a safe app-sandbox input filename"
        }
        inputFile = context.filesDir.resolve(name)
        require(inputFile!!.isFile) { "Missing coordinator input: ${inputFile!!.path}" }
        val input = decodeInput(inputFile!!.readText())
        previousRecord = storageRead(KEY)
        storageWrite(KEY, credentialRecord(input.getString("access_token")))
        preferences.edit()
            .clear()
            .putString(MainActivity.FORGE_COORDINATOR_API_URL, input.getString("api_url"))
            .putString(MainActivity.FORGE_COORDINATOR_CONVERSATION_ID, input.getString("conversation_id"))
            .putString(MainActivity.FORGE_COORDINATOR_CLIENT_INSTANCE_ID, input.getString("client_instance_id"))
            .putString(MainActivity.FORGE_COORDINATOR_SESSION_VIEW, input.getJSONObject("session_view").toString())
            .putString(MainActivity.FORGE_COORDINATOR_RESOURCE_VIEW, input.getJSONObject("resource_view").toString())
            .putLong(MainActivity.FORGE_COORDINATOR_EXPECTED_VERSION, input.getLong("expected_version"))
            .putLong(MainActivity.FORGE_COORDINATOR_AFTER_CURSOR, input.getLong("after_cursor"))
            .putString(MainActivity.FORGE_COORDINATOR_PROMPT, input.getString("prompt"))
            .putString(MainActivity.FORGE_COORDINATOR_IDEMPOTENCY_KEY, input.getString("idempotency_key"))
            .putInt(MainActivity.FORGE_COORDINATOR_RUN_INDEX, 1)
            .apply()
    }

    @After
    fun tearDown() {
        scenario?.close()
        if (previousRecord == null) storageDelete(KEY) else storageWrite(KEY, previousRecord!!)
        preferences.edit().clear().commit()
        inputFile?.delete()
    }

    @Test
    fun realCoordinatorPromptReplaySurvivesActivityRecreation() {
        val input = decodeInput(inputFile!!.readText())
        val expectedAggregateVersion = input.getLong("expected_version") + 1
        val intent = FlutterActivity.withNewEngine().build(context).apply {
            putExtra("dart_entrypoint", "forgeAndroidCoordinatorInstrumentationMain")
            setClass(context, MainActivity::class.java)
        }
        scenario = ActivityScenario.launch(intent)

        awaitCompletion(1)
        assertCompletion(expectedAggregateVersion, 1)
        val firstPaths = requestPaths()
        assertPromptOnly(firstPaths, input.getString("conversation_id"))

        preferences.edit().putInt(MainActivity.FORGE_COORDINATOR_RUN_INDEX, 2).apply()
        scenario!!.recreate()
        awaitCompletion(2)
        assertCompletion(expectedAggregateVersion, 2)
        val allPaths = requestPaths()
        assertPromptOnly(
            allPaths.drop(firstPaths.size),
            input.getString("conversation_id"),
        )
        assertTrue("The recreated Activity did not issue new API calls", allPaths.size > firstPaths.size)
    }

    private fun awaitCompletion(expected: Int) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(120)
        while (System.nanoTime() < deadline) {
            instrumentation.waitForIdleSync()
            if (preferences.getInt(MainActivity.FORGE_COORDINATOR_COMPLETION_COUNT, 0) >= expected) return
            Thread.sleep(100)
        }
        error(
            "Timed out waiting for coordinator completion $expected; " +
                "observed ${preferences.getInt(MainActivity.FORGE_COORDINATOR_COMPLETION_COUNT, 0)} " +
                "error=${preferences.getString(MainActivity.FORGE_COORDINATOR_LAST_ERROR, null)}",
        )
    }

    private fun assertCompletion(expectedAggregateVersion: Long, expectedRunIndex: Int) {
        assertTrue(preferences.getBoolean(MainActivity.FORGE_COORDINATOR_LAST_OK, false))
        assertTrue(preferences.getBoolean(MainActivity.FORGE_INSTRUMENTATION_LAST_AUTHORIZED, false))
        val report = preferences.getString(MainActivity.FORGE_COORDINATOR_LAST_REPORT, null)
        assertNotNull(report)
        val value = JSONObject(report!!)
        assertEquals(expectedRunIndex, value.getInt("run_index"))
        assertEquals(expectedAggregateVersion, value.getLong("aggregate_version"))
        assertTrue(value.getBoolean("replayed"))
        assertTrue(value.getString("prompt_id").isNotEmpty())
    }

    private fun requestPaths(): List<String> = preferences
        .getString(MainActivity.FORGE_INSTRUMENTATION_REQUEST_PATHS, "")
        .orEmpty()
        .lineSequence()
        .filter { it.isNotEmpty() }
        .toList()

    private fun assertPromptOnly(paths: List<String>, conversationID: String) {
        assertTrue("No authenticated API requests were recorded", paths.isNotEmpty())
        assertTrue("The mobile instance projection was not read before Conversations", paths.size >= 3)
        assertEquals("/api/v1/client-instances/session-view", paths.first())
        assertEquals("/api/v1/client-instances/resource-view", paths[1])
        assertEquals("/api/v1/conversations", paths[2])
        val promptPath = "/api/v1/conversations/$conversationID/prompts"
        for (path in paths) {
            assertTrue(
                "Unexpected mobile Coordinator path: $path",
                path == "/api/v1/client-instances/session-view" ||
                    path == "/api/v1/client-instances/resource-view" ||
                    path == "/api/v1/conversations" ||
                    path == "/api/v1/conversation-changes" ||
                    path == promptPath,
            )
            assertFalse(path.contains("/devices"))
            assertFalse(path.contains("run-intents"))
            assertFalse(path.contains("placement"))
            assertFalse(path.contains("dispatch"))
        }
    }

    private fun decodeInput(raw: String): JSONObject {
        val value = JSONObject(raw)
        val expected = setOf(
            "api_url",
            "access_token",
            "conversation_id",
            "client_instance_id",
            "session_view",
            "resource_view",
            "expected_version",
            "after_cursor",
            "prompt",
            "idempotency_key",
        )
        val actual = buildSet {
            val keys = value.keys()
            while (keys.hasNext()) add(keys.next())
        }
        require(actual == expected) { "Unexpected coordinator input fields" }
        for (key in listOf("api_url", "access_token", "conversation_id", "prompt", "idempotency_key")) {
            val string = value.getString(key)
            require(string.isNotEmpty() && !string.contains(Regex("[\\r\\n\\u0000]"))) {
                "Invalid coordinator input $key"
            }
        }
        require(value.getLong("expected_version") in 1..9007199254740991)
        require(value.getLong("after_cursor") in 0..9007199254740991)
        validateSessionResourcePair(
            value.getJSONObject("session_view"),
            value.getJSONObject("resource_view"),
            value.getString("conversation_id"),
            value.getString("client_instance_id"),
        )
        return value
    }

    private fun validateSessionResourcePair(
        sessionView: JSONObject,
        resourceView: JSONObject,
        conversationID: String,
        clientInstanceID: String,
    ) {
        val session = validateView(sessionView, resource = false)
        val resource = validateView(resourceView, resource = true)
        require(session.owner == resource.owner) { "Session/resource owner drift" }
        require(session.instances == resource.instances) { "Session/resource instance drift" }
        val selected = session.instances.firstOrNull { it.id == clientInstanceID }
            ?: error("Selected client instance is missing")
        require(selected.kind == "mobile") { "Selected client instance is not mobile" }
        require(conversationID in selected.sessions) {
            "Conversation is hidden from selected client instance"
        }
    }

    private fun validateView(value: JSONObject, resource: Boolean): Observation {
        val sessionKeys = setOf(
            "schema_version",
            "evaluation_mode",
            "owner_declaration",
            "owner_declaration_unverified",
            "instances",
            "read_only",
            "authority",
        )
        val expected = if (resource) sessionKeys + setOf(
            "devices",
            "device_attributes_unverified",
        ) else sessionKeys
        require(jsonKeys(value) == expected) { "Unexpected client-instance view fields" }
        require(
            value.getString("schema_version") ==
                if (resource) "forge.client-instance-resource-view/v1"
                else "forge.client-instance-session-view/v1",
        )
        require(
            value.getString("evaluation_mode") ==
                if (resource) "owner_bound_instance_resource_view_only"
                else "owner_bound_session_view_only",
        )
        require(value.get("owner_declaration_unverified") == true)
        require(value.get("read_only") == true)
        validateAuthority(value.getJSONObject("authority"))
        val owner = validateOwner(value.getJSONObject("owner_declaration"))
        val rawInstances = value.getJSONArray("instances")
        require(rawInstances.length() <= 128)
        val instances = buildList {
            for (index in 0 until rawInstances.length()) {
                add(validateInstance(rawInstances.getJSONObject(index)))
            }
        }
        require(instances.map { it.id } == instances.map { it.id }.distinct().sorted())
        if (resource) {
            require(value.get("device_attributes_unverified") == true)
            validateDevices(value.getJSONArray("devices"), owner)
        }
        return Observation(owner, instances)
    }

    private fun validateInstance(value: JSONObject): InstanceObservation {
        require(
            jsonKeys(value) == setOf(
                "instance_id",
                "client_kind",
                "session_ids",
                "observed_at_ms",
                "status",
            ),
        )
        val id = identifier(value.getString("instance_id"))
        require(value.getString("client_kind") in setOf("cli", "tui", "web", "app", "mobile"))
        val sessionsJSON = value.getJSONArray("session_ids")
        require(sessionsJSON.length() <= 128)
        val sessions = buildList {
            for (index in 0 until sessionsJSON.length()) add(identifier(sessionsJSON.getString(index)))
        }
        require(sessions == sessions.distinct().sorted())
        val observed = safeLong(value.get("observed_at_ms"), positive = true)
        require(value.getString("status") in setOf("active", "idle", "offline", "unknown"))
        return InstanceObservation(id, value.getString("client_kind"), sessions, observed, value.getString("status"))
    }

    private fun validateDevices(value: org.json.JSONArray, owner: Owner) {
        require(value.length() <= 128)
        val order = buildList {
            for (index in 0 until value.length()) {
                val device = value.getJSONObject(index)
                require(
                    jsonKeys(device) == setOf(
                        "device_id", "runner_instance_id", "owner", "revision", "generation",
                        "heartbeat_sequence", "observed_at_ms", "approval_state", "cordon_state",
                        "reservation_state", "liveness", "os", "architecture", "cpu_cores",
                        "available_cpu_cores", "memory_bytes", "available_memory_bytes",
                        "storage_bytes", "available_storage_bytes", "gpu_count",
                        "available_gpu_memory_bytes",
                    ),
                )
                require(validateOwner(device.getJSONObject("owner")) == owner)
                val deviceID = identifier(device.getString("device_id"))
                val runnerID = identifier(device.getString("runner_instance_id"))
                for (key in listOf("revision", "generation", "heartbeat_sequence", "observed_at_ms")) {
                    safeLong(device.get(key), positive = true)
                }
                for (key in listOf(
                    "cpu_cores", "available_cpu_cores", "memory_bytes", "available_memory_bytes",
                    "storage_bytes", "available_storage_bytes", "gpu_count", "available_gpu_memory_bytes",
                )) {
                    safeLong(device.get(key), positive = false)
                }
                require(
                    device.getLong("available_cpu_cores") <= device.getLong("cpu_cores") &&
                        device.getLong("available_memory_bytes") <= device.getLong("memory_bytes") &&
                        device.getLong("available_storage_bytes") <= device.getLong("storage_bytes"),
                )
                require(device.getString("approval_state") in setOf("approved", "pending", "revoked", "unknown"))
                require(device.getString("cordon_state") in setOf("clear", "cordoned", "unknown"))
                require(device.getString("reservation_state") in setOf("none", "reserved", "unknown"))
                require(device.getString("liveness") in setOf("online", "offline", "unknown"))
                text(device.getString("os"))
                text(device.getString("architecture"))
                add(deviceID to runnerID)
            }
        }
        require(order == order.distinct().sortedWith(compareBy({ it.first }, { it.second })))
    }

    private fun validateOwner(value: JSONObject): Owner {
        require(jsonKeys(value) == setOf("issuer", "subject", "tenant_id"))
        return Owner(
            text(value.getString("issuer")),
            text(value.getString("subject")),
            text(value.getString("tenant_id")),
        )
    }

    private fun validateAuthority(value: JSONObject) {
        val keys = setOf(
            "owner_authenticated", "session_read_authorized", "prompt_write_authorized",
            "device_identity_verified", "reservation_created", "execution_authorized",
            "dispatch_performed", "audit_published",
        )
        require(jsonKeys(value) == keys)
        for (key in keys) require(value.get(key) == false)
    }

    private fun jsonKeys(value: JSONObject): Set<String> = buildSet {
        val keys = value.keys()
        while (keys.hasNext()) add(keys.next())
    }

    private fun identifier(value: String): String {
        require(value.matches(Regex("[A-Za-z0-9][A-Za-z0-9._:+/-]{0,127}")))
        return value
    }

    private fun text(value: String): String {
        require(value.isNotEmpty() && value.length <= 512 && value.none { it < ' ' || it == '\u007f' })
        return value
    }

    private fun safeLong(value: Any, positive: Boolean): Long {
        require(value is Int || value is Long)
        val number = (value as Number).toLong()
        require((number >= if (positive) 1L else 0L) && number <= 9007199254740991L)
        return number
    }

    private data class Owner(val issuer: String, val subject: String, val tenant: String)

    private data class InstanceObservation(
        val id: String,
        val kind: String,
        val sessions: List<String>,
        val observedAt: Long,
        val status: String,
    )

    private data class Observation(
        val owner: Owner,
        val instances: List<InstanceObservation>,
    )

    private fun credentialRecord(accessToken: String): String = JSONObject()
        .put("version", 1)
        .put("client_id", "forge-console")
        .put("access_token", accessToken)
        .put("session_id", "android-coordinator-instrumentation")
        .put("refresh_token", JSONObject.NULL)
        .toString()

    private fun storageRead(key: String): String? {
        val done = CountDownLatch(1)
        var value: String? = null
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(result: Void?) {
                try {
                    value = storage.read(key)
                } catch (error: Exception) {
                    failure = error
                }
                done.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                done.countDown()
            }
        })
        check(done.await(20, TimeUnit.SECONDS)) { "Secure storage read timed out" }
        check(failure == null) { "Secure storage read failed: $failure" }
        return value
    }

    private fun storageWrite(key: String, value: String) {
        val done = CountDownLatch(1)
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(result: Void?) {
                try {
                    storage.write(key, value)
                } catch (error: Exception) {
                    failure = error
                }
                done.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                done.countDown()
            }
        })
        check(done.await(20, TimeUnit.SECONDS)) { "Secure storage write timed out" }
        check(failure == null) { "Secure storage write failed: $failure" }
    }

    private fun storageDelete(key: String) {
        val done = CountDownLatch(1)
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(result: Void?) {
                try {
                    storage.delete(key)
                } catch (error: Exception) {
                    failure = error
                }
                done.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                done.countDown()
            }
        })
        check(done.await(20, TimeUnit.SECONDS)) { "Secure storage delete timed out" }
        check(failure == null) { "Secure storage delete failed: $failure" }
    }

    private companion object {
        const val CONFIG_ARGUMENT = "forge_coordinator_config"
        val SAFE_NAME = Regex("[A-Za-z0-9._-]{1,96}")
        const val KEY = "forge.oauth.credentials.v1"
    }
}
