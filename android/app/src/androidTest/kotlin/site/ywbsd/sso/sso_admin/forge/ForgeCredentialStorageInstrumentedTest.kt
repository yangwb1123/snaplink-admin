package site.ywbsd.sso.sso_admin.forge

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Exercises the Android secure-store backend used by ForgeCredentialStore.
 *
 * This deliberately stops at the encrypted credential record boundary. It
 * does not start Flutter, MainActivity, an authenticated client, or any Hub
 * route. The host-side Flutter test covers the Dart record and API lifecycle.
 */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 23)
class ForgeCredentialStorageInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val namespace = "forge.instrumentation.${UUID.randomUUID()}"
    private val config = FlutterSecureStorageConfig(
        mapOf("storageNamespace" to namespace),
    )
    private val key = "forge.oauth.credentials.v1.instrumentation"

    @Before
    fun clearBefore() {
        openStorage().deleteAll()
    }

    @After
    fun clearAfter() {
        openStorage().deleteAll()
    }

    @Test
    fun encryptedForgeRecordSurvivesAColdStorageInstance() {
        val record =
            """
            {"version":1,"client_id":"forge.instrumentation","access_token":"token-${UUID.randomUUID()}","session_id":"android-test","refresh_token":"refresh-token"}
            """.trimIndent()

        openStorage().write(key, record)

        // A new backend instance models the storage part of a native cold
        // start. This test does not claim process kill or Activity recreation.
        // The Android Keystore key and encrypted preferences are reused by the
        // second instance without exposing the bearer in process memory.
        val restored = openStorage().read(key)
        assertEquals(record, restored)

        openStorage().delete(key)
        assertNull(openStorage().read(key))
    }

    private fun openStorage(): FlutterSecureStorage {
        val storage = FlutterSecureStorage(context)
        val completed = CountDownLatch(1)
        var failure: Exception? = null
        storage.initialize(config, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(result: Void?) {
                completed.countDown()
            }

            override fun onError(error: Exception) {
                failure = error
                completed.countDown()
            }
        })
        check(completed.await(20, TimeUnit.SECONDS)) {
            "Android secure storage initialization timed out"
        }
        check(failure == null) { "Android secure storage initialization failed: $failure" }
        return storage
    }
}
