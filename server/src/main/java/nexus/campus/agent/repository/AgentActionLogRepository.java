package nexus.campus.agent.repository;

import nexus.campus.agent.entity.AgentActionLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AgentActionLogRepository extends JpaRepository<AgentActionLog, Integer> {
    List<AgentActionLog> findByUser_IdOrderByCreatedAtDesc(Integer userId);
}
