package nexus.campus.agent.memory.repository;

import nexus.campus.agent.memory.entity.AgentMemory;
import nexus.campus.common.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@DataJpaTest
class AgentMemoryRepositoryTest {
    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private AgentMemoryRepository repository;

    @Test
    void touchRecallUpdatesAccessMetadataInH2() {
        User user = new User();
        user.setUsername("memory-owner");
        user.setEmail("memory-owner@example.test");
        user.setPassword("test-password");
        user.setJoinedAt(Instant.now());
        entityManager.persist(user);

        AgentMemory memory = new AgentMemory();
        memory.setUser(user);
        memory.setKind("project");
        memory.setTitle("Nexus memory integration");
        memory.setContent("Validate the JPQL recall update against a real database.");
        memory.setTags("[]");
        entityManager.persistAndFlush(memory);

        int updated = repository.touchRecall(List.of(memory.getId()), LocalDateTime.now());
        entityManager.flush();
        entityManager.clear();

        AgentMemory reloaded = repository.findById(memory.getId()).orElseThrow();
        assertEquals(1, updated);
        assertEquals(1, reloaded.getAccessCount());
        assertNotNull(reloaded.getLastAccessedAt());
    }
}
