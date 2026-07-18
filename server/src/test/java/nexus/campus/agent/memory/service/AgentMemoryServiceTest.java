package nexus.campus.agent.memory.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.agent.memory.dto.AgentMemoryWriteRequest;
import nexus.campus.agent.memory.entity.AgentMemory;
import nexus.campus.agent.memory.repository.AgentMemoryRepository;
import nexus.campus.agent.memory.repository.MatchMemoryShareRepository;
import nexus.campus.common.exception.ApiException;
import nexus.campus.help.repository.HelpMatchRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AgentMemoryServiceTest {
    private AgentMemoryRepository memoryRepository;
    private AgentMemoryService service;

    @BeforeEach
    void setUp() {
        memoryRepository = mock(AgentMemoryRepository.class);
        service = new AgentMemoryService(
                memoryRepository,
                mock(MatchMemoryShareRepository.class),
                mock(HelpMatchRepository.class),
                new ObjectMapper().findAndRegisterModules());
    }

    @Test
    void createNormalizesDurableTaskContext() {
        when(memoryRepository.save(any(AgentMemory.class))).thenAnswer(invocation -> {
            AgentMemory memory = invocation.getArgument(0);
            memory.setId(17);
            return memory;
        });
        AgentMemoryWriteRequest request = new AgentMemoryWriteRequest();
        request.setKind("environment");
        request.setTitle("Campus GPU workstation");
        request.setContent("The workstation is reachable only from the campus network.");
        request.setTags(List.of("Campus Network", "GPU"));
        request.setImportance(5);
        request.setPinned(true);
        request.setSharePolicy("ask_each_time");

        var response = service.create(3, request);

        assertEquals(17, response.getId());
        assertEquals("environment", response.getKind());
        assertEquals(List.of("campus-network", "gpu"), response.getTags());
        assertEquals(5, response.getImportance());
        assertTrue(response.getPinned());
        assertEquals("ask_each_time", response.getSharePolicy());
    }

    @Test
    void rejectsCredentialLikeMemoryContent() {
        AgentMemoryWriteRequest request = new AgentMemoryWriteRequest();
        request.setKind("environment");
        request.setTitle("Server access");
        request.setContent("api_key = sk-this-must-not-be-stored");

        ApiException exception = assertThrows(
                ApiException.class, () -> service.create(3, request));

        assertEquals(400, exception.getStatus());
        verify(memoryRepository, never()).save(any());
    }

    @Test
    void recallScoreRewardsRelevantPinnedMemory() {
        AgentMemory relevant = memory(
                "Available dataset transfer path",
                "Use the campus network and a temporary HTTP server for the dataset.",
                5,
                true);
        AgentMemory unrelated = memory(
                "Lunch preference",
                "The user usually prefers a light lunch.",
                3,
                false);

        double relevantScore = service.score(
                relevant, "dataset campus", List.of("dataset", "campus"));
        double unrelatedScore = service.score(
                unrelated, "dataset campus", List.of("dataset", "campus"));

        assertTrue(relevantScore > unrelatedScore + 5);
    }

    @Test
    void updateCanExplicitlyClearExpiry() {
        AgentMemory memory = memory(
                "Temporary lab access",
                "The lab is available for the current project.",
                3,
                false);
        memory.setId(9);
        memory.setExpiresAt(LocalDateTime.now().plusDays(2));
        when(memoryRepository.findByIdAndUser_Id(9, 3)).thenReturn(Optional.of(memory));
        when(memoryRepository.save(memory)).thenReturn(memory);

        AgentMemoryWriteRequest request = new AgentMemoryWriteRequest();
        request.setClearExpiresAt(true);

        var response = service.update(3, 9, request);

        assertNull(response.getExpiresAt());
    }

    @Test
    void updateRejectsConflictingExpiryInstructions() {
        AgentMemory memory = memory(
                "Temporary lab access",
                "The lab is available for the current project.",
                3,
                false);
        memory.setId(9);
        when(memoryRepository.findByIdAndUser_Id(9, 3)).thenReturn(Optional.of(memory));

        AgentMemoryWriteRequest request = new AgentMemoryWriteRequest();
        request.setExpiresAt(LocalDateTime.now().plusDays(2));
        request.setClearExpiresAt(true);

        ApiException exception = assertThrows(
                ApiException.class, () -> service.update(3, 9, request));

        assertEquals(400, exception.getStatus());
        verify(memoryRepository, never()).save(any());
    }

    private AgentMemory memory(String title, String content, int importance, boolean pinned) {
        AgentMemory memory = new AgentMemory();
        memory.setKind("resource");
        memory.setTitle(title);
        memory.setContent(content);
        memory.setImportance(importance);
        memory.setPinned(pinned);
        memory.setTags("[]");
        memory.setUpdatedAt(LocalDateTime.now());
        return memory;
    }
}
