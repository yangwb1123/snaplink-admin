package site.ywbsd.sso.sso_admin.workspace

import org.junit.Assert.*
import org.junit.Test

class WorkspaceRequestStateTest {
    @Test
    fun onlyOneRequestOwnsThePicker() {
        val state = WorkspaceRequestState()
        val token = state.begin()
        assertTrue(state.owns(token))
        assertEquals("busy", assertThrows(WorkspaceFileFailure::class.java) { state.begin() }.code)
        assertTrue(state.finish(token))
        assertTrue(state.owns(state.begin()))
    }

    @Test
    fun duplicateAndStaleCallbacksCannotCompleteANewRequest() {
        val state = WorkspaceRequestState()
        val old = state.begin()
        assertFalse(state.finish(old + 1))
        assertTrue(state.finish(old))
        assertFalse(state.finish(old))
        val current = state.begin()
        assertNotEquals(old, current)
        assertFalse(state.finish(old))
        assertTrue(state.owns(current))
    }

    @Test
    fun destructionPreventsCompletionAndFutureRequests() {
        val state = WorkspaceRequestState()
        val token = state.begin()
        state.close()
        state.close()
        assertFalse(state.finish(token))
        assertFalse(state.owns(token))
        assertEquals("unavailable", assertThrows(WorkspaceFileFailure::class.java) { state.begin() }.code)
    }

    @Test
    fun activityRecreationDoesNotReuseOutstandingRequestCode() {
        val old = WorkspaceRequestState()
        val oldCode = old.begin()
        old.close()
        val recreated = WorkspaceRequestState()
        val newCode = recreated.begin()
        assertNotEquals(oldCode, newCode)
        assertFalse(recreated.finish(oldCode))
        assertTrue(recreated.finish(newCode))
    }
}
