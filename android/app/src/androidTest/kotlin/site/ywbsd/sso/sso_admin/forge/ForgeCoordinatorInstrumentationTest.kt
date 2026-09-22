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
        assertPromptOnly(allPaths, input.getString("conversation_id"))
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
        val promptPath = "/api/v1/conversations/$conversationID/prompts"
        for (path in paths) {
            assertTrue(
                "Unexpected mobile Coordinator path: $path",
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
        return value
    }

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
