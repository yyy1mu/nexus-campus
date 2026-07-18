package nexus.campus.agent.memory.controller;

import nexus.campus.agent.memory.dto.MatchMemoryShareRequest;
import nexus.campus.agent.memory.dto.MatchMemoryShareResponse;
import nexus.campus.agent.memory.service.AgentMemoryService;
import nexus.campus.common.entity.User;
import nexus.campus.common.logging.ActionLogService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class AgentMemoryControllerTest {
    private AgentMemoryService memoryService;
    private AgentWriteGuard guard;
    private AgentMemoryController controller;
    private User user;

    @BeforeEach
    void setUp() {
        memoryService = mock(AgentMemoryService.class);
        guard = mock(AgentWriteGuard.class);
        controller = new AgentMemoryController(
                memoryService, mock(ActionLogService.class), guard);
        user = new User();
        user.setId(7);
    }

    @Test
    void sharingRequiresMatchingPermissionAndConfirmation() {
        MatchMemoryShareRequest request = new MatchMemoryShareRequest();
        request.setMemoryIds(List.of(11));
        request.setUserConfirmed(true);
        when(memoryService.share(7, 5, request)).thenReturn(List.of());

        controller.share(5, user, request);

        verify(guard).requireMatching(
                eq(user), eq(Map.of("userConfirmed", true)), eq("share memory with a match"));
        verify(memoryService).share(7, 5, request);
    }

    @Test
    void revocationOnlyRequiresConfirmationSoItRemainsAvailableAfterOptOut() {
        MatchMemoryShareResponse response = MatchMemoryShareResponse.builder()
                .id(13)
                .matchId(5)
                .ownerUserId(7)
                .build();
        when(memoryService.revoke(7, 5, 13)).thenReturn(response);
        Map<String, Object> body = Map.of("revoked", true, "userConfirmed", true);

        controller.revoke(5, 13, user, body);

        verify(guard).requireConfirmedUser(user, body);
        verify(guard, never()).requireMatching(any(), any(), any());
        verify(memoryService).revoke(7, 5, 13);
    }
}
