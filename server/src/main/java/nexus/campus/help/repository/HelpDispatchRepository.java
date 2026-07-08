package nexus.campus.help.repository;

import nexus.campus.help.entity.HelpDispatch;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface HelpDispatchRepository extends JpaRepository<HelpDispatch, Integer> {
    Optional<HelpDispatch> findByHelpRequestIdAndHelperId(Integer helpRequestId, Integer helperId);
    List<HelpDispatch> findByHelpRequestIdOrderByCreatedAtDesc(Integer helpRequestId);
    List<HelpDispatch> findByHelperIdOrderByCreatedAtDesc(Integer helperId);
}
