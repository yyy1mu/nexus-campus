package nexus.campus.agent.repository;

import nexus.campus.agent.entity.UserCapability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserCapabilityRepository extends JpaRepository<UserCapability, Integer> {
    List<UserCapability> findByIsActiveTrue();

    List<UserCapability> findByUser_IdAndIsActiveTrue(Integer userId);

    Optional<UserCapability> findByUser_IdAndLabel(Integer userId, String label);

    List<UserCapability> findByLabelAndIsActiveTrue(String label);

    List<UserCapability> findByUser_Id(Integer userId);
}
