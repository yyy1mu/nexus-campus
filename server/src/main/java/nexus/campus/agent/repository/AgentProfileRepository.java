package nexus.campus.agent.repository;

import nexus.campus.agent.entity.AgentProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AgentProfileRepository extends JpaRepository<AgentProfile, Integer> {
    Optional<AgentProfile> findByUser_Id(Integer userId);
}
