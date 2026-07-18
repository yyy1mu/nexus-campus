package nexus.campus.agent.memory.repository;

import nexus.campus.agent.memory.entity.MatchMemoryShare;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MatchMemoryShareRepository extends JpaRepository<MatchMemoryShare, Integer> {
    List<MatchMemoryShare> findByMatch_IdAndRevokedAtIsNullOrderByCreatedAtAsc(Integer matchId);
    Optional<MatchMemoryShare> findByMatch_IdAndMemory_Id(Integer matchId, Integer memoryId);
    Optional<MatchMemoryShare> findByIdAndMatch_Id(Integer id, Integer matchId);
    void deleteByMemory_Id(Integer memoryId);
}
