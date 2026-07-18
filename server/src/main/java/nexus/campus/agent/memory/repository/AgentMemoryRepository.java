package nexus.campus.agent.memory.repository;

import nexus.campus.agent.memory.entity.AgentMemory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface AgentMemoryRepository extends JpaRepository<AgentMemory, Integer> {
    List<AgentMemory> findByUser_IdOrderByPinnedDescImportanceDescUpdatedAtDesc(Integer userId);
    Optional<AgentMemory> findByIdAndUser_Id(Integer id, Integer userId);
    long countByUser_IdAndStatus(Integer userId, String status);

    @Modifying
    @Query("""
            update AgentMemory memory
            set memory.lastAccessedAt = :accessedAt,
                memory.accessCount = memory.accessCount + 1
            where memory.id in :ids
            """)
    int touchRecall(
            @Param("ids") List<Integer> ids,
            @Param("accessedAt") LocalDateTime accessedAt);
}
