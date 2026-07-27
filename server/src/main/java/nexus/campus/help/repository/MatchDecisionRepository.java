package nexus.campus.help.repository;

import nexus.campus.help.entity.MatchDecision;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MatchDecisionRepository extends JpaRepository<MatchDecision, Integer> {
    List<MatchDecision> findByMatchIdOrderByCreatedAtAscIdAsc(Integer matchId);
    Optional<MatchDecision> findByIdAndMatchId(Integer id, Integer matchId);
    Optional<MatchDecision> findByMatchIdAndClientRequestId(Integer matchId, String clientRequestId);
    List<MatchDecision> findByMatchIdAndStatus(Integer matchId, String status);
    List<MatchDecision> findByStatusAndAssignedRoleAndMatch_Helper_Id(
            String status, String assignedRole, Integer helperId);
    List<MatchDecision> findByStatusAndAssignedRoleAndMatch_HelpRequest_Requester_Id(
            String status, String assignedRole, Integer requesterId);
}
