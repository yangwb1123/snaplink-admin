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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import site.ywbsd.sso.sso_admin.MainActivity

/**
 * Runs the real Flutter engine and MainActivity around a cold Forge Gate.
 *
 * The Dart entrypoint restores a Forge-shaped record through the production
 * ForgeCredentialStore, then serves the read-only Conversation/Prompt pages
 * from a bounded in-process HTTP fixture. MainActivity records the requests
 * only through a debug-gated MethodChannel, allowing this test to prove that
 * the Android secure record is used again after Activity recreation without
 * opening a production device or execution route.
 */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 23)
class ForgeMainActivityLifecycleInstrumentedTest {
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

    @Before
    fun setUp() {
        previousRecord = storageRead(KEY)
        storageWrite(KEY, CREDENTIAL_RECORD)
        preferences.edit().clear().commit()
    }

    @After
    fun tearDown() {
        scenario?.close()
        if (previousRecord == null) storageDelete(KEY) else storageWrite(KEY, previousRecord!!)
        preferences.edit().clear().commit()
    }

    @Test
    fun realMainActivityRestoresForgeSessionAfterRecreation() {
        val intent = FlutterActivity.withNewEngine().build(context).apply {
            // FlutterActivity's current embedding exposes the entrypoint as
            // an Intent extra rather than a builder method.
            putExtra("dart_entrypoint", "forgeAndroidInstrumentationMain")
            setClass(context, MainActivity::class.java)
        }
        scenario = ActivityScenario.launch(intent)

        awaitRequestCountAtLeast(1)
        assertEquals(
            "/api/v1/conversations",
            preferences.getString("last_path", null),
        )
        assertTrue(preferences.getBoolean("last_authorized", false))
        val firstCount = preferences.getInt("request_count", 0)
        assertTrue("Forge Gate did not make enough bootstrap reads", firstCount >= 1)

        scenario!!.recreate()
        awaitRequestCountAtLeast(firstCount + 1)
        assertEquals(
            "/api/v1/conversations",
            preferences.getString("last_path", null),
        )
        assertTrue(preferences.getBoolean("last_authorized", false))
    }

    private fun awaitRequestCountAtLeast(expected: Int) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(45)
        while (System.nanoTime() < deadline) {
            instrumentation.waitForIdleSync()
            if (preferences.getInt("request_count", 0) >= expected) return
            Thread.sleep(100)
        }
        error(
            "Timed out waiting for Forge instrumentation request count >= $expected; " +
                "observed ${preferences.getInt("request_count", 0)}",
        )
    }

    private fun storageRead(key: String): String? {
        val result = CountDownLatch(1)
        var value: String? = null
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(resultValue: Void?) {
                try {
                    value = storage.read(key)
                } catch (error: Exception) {
                    failure = error
                }
                result.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                result.countDown()
            }
        })
        check(result.await(20, TimeUnit.SECONDS)) { "Secure storage read timed out" }
        check(failure == null) { "Secure storage read failed: $failure" }
        return value
    }

    private fun storageWrite(key: String, value: String) {
        val result = CountDownLatch(1)
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(resultValue: Void?) {
                try {
                    storage.write(key, value)
                } catch (error: Exception) {
                    failure = error
                }
                result.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                result.countDown()
            }
        })
        check(result.await(20, TimeUnit.SECONDS)) { "Secure storage write timed out" }
        check(failure == null) { "Secure storage write failed: $failure" }
    }

    private fun storageDelete(key: String) {
        val result = CountDownLatch(1)
        var failure: Exception? = null
        storage.initialize(storageConfig, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(resultValue: Void?) {
                try {
                    storage.delete(key)
                } catch (error: Exception) {
                    failure = error
                }
                result.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                result.countDown()
            }
        })
        check(result.await(20, TimeUnit.SECONDS)) { "Secure storage delete timed out" }
        check(failure == null) { "Secure storage delete failed: $failure" }
    }

    private companion object {
        const val KEY = "forge.oauth.credentials.v1"
        const val CREDENTIAL_RECORD =
            "{\"version\":1,\"client_id\":\"forge-console\",\"access_token\":\"forge-android-instrumentation-token\",\"session_id\":\"android-lifecycle\",\"refresh_token\":null}"
    }
}
