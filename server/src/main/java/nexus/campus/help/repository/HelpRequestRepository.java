package nexus.campus.help.repository;

import nexus.campus.help.entity.HelpRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;

public interface HelpRequestRepository extends JpaRepository<HelpRequest, Integer>,
        JpaSpecificationExecutor<HelpRequest> {
    List<HelpRequest> findByRequesterIdOrderByCreatedAtDesc(Integer userId);
    List<HelpRequest> findByStatusOrderByCreatedAtDesc(String status);
}
