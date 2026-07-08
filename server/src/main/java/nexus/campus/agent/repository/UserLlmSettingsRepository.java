package nexus.campus.agent.repository;

import nexus.campus.agent.entity.UserLlmSettings;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserLlmSettingsRepository extends JpaRepository<UserLlmSettings, Integer> {
}
