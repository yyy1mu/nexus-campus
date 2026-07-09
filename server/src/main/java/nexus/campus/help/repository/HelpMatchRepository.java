package nexus.campus.help.repository;

import nexus.campus.help.entity.HelpMatch;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface HelpMatchRepository extends JpaRepository<HelpMatch, Integer> {
    Optional<HelpMatch> findByHelpRequestIdAndHelperId(Integer helpRequestId, Integer helperId);
    List<HelpMatch> findByHelpRequestIdOrderByCreatedAtDesc(Integer helpRequestId);
    List<HelpMatch> findByHelperIdOrderByCreatedAtDesc(Integer helperId);
    List<HelpMatch> findByHelpRequest_Requester_IdOrderByCreatedAtDesc(Integer requesterId);
}
