package nexus.campus.help.controller;

import nexus.campus.common.entity.User;
import nexus.campus.common.logging.ActionLogService;
import nexus.campus.help.service.MatchCollaborationService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class MatchWorkspaceControllerTest {

    private MatchCollaborationService collaboration;
    private MatchWorkspaceController controller;
    private User user;

    @BeforeEach
    void setUp() {
        collaboration = mock(MatchCollaborationService.class);
        controller = new MatchWorkspaceController(
                collaboration, mock(AgentWriteGuard.class), mock(ActionLogService.class));
        user = new User();
        user.setId(5);
    }

    @Test
    void concurrentDuplicateTaskCreateReturnsWinnersRecord() {
        Map<String, Object> body = Map.of(
                "title", "Verify checksum", "clientRequestId", "task-1", "userConfirmed", true);
        when(collaboration.createTask(eq(12), eq(5), any()))
                .thenThrow(new DataIntegrityViolationException("duplicate key"));
        when(collaboration.taskReplay(12, 5, "task-1"))
                .thenReturn(Optional.of(Map.of("id", 21, "title", "Verify checksum")));

        var response = controller.createTask(12, user, body);

        assertEquals(21, response.getData().get("id"));
    }

    @Test
    void integrityViolationWithoutReplayableRecordIsRethrown() {
        Map<String, Object> body = Map.of("title", "No client id", "userConfirmed", true);
        when(collaboration.createTask(eq(12), eq(5), any()))
                .thenThrow(new DataIntegrityViolationException("duplicate key"));
        when(collaboration.taskReplay(12, 5, null)).thenReturn(Optional.empty());

        assertThrows(DataIntegrityViolationException.class,
                () -> controller.createTask(12, user, body));
    }
}
