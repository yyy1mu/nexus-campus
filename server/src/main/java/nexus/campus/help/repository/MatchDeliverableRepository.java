package nexus.campus.help.repository;

import nexus.campus.help.entity.MatchDeliverable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MatchDeliverableRepository extends JpaRepository<MatchDeliverable, Integer> {
    List<MatchDeliverable> findByMatchIdOrderByCreatedAtAscIdAsc(Integer matchId);
    Optional<MatchDeliverable> findByIdAndMatchId(Integer id, Integer matchId);
    Optional<MatchDeliverable> findByMatchIdAndClientRequestId(Integer matchId, String clientRequestId);
    List<MatchDeliverable> findByMatchIdAndStatus(Integer matchId, String status);
    List<MatchDeliverable> findByStatusAndSubmitterRoleAndMatch_Helper_Id(
            String status, String submitterRole, Integer helperId);
    List<MatchDeliverable> findByStatusAndSubmitterRoleAndMatch_HelpRequest_Requester_Id(
            String status, String submitterRole, Integer requesterId);
}
