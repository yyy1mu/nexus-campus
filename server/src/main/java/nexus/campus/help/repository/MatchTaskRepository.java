package nexus.campus.help.repository;

import nexus.campus.help.entity.MatchTask;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MatchTaskRepository extends JpaRepository<MatchTask, Integer> {
    List<MatchTask> findByMatchIdOrderByOrderIndexAscIdAsc(Integer matchId);
    Optional<MatchTask> findByIdAndMatchId(Integer id, Integer matchId);
    Optional<MatchTask> findByMatchIdAndClientRequestId(Integer matchId, String clientRequestId);
    long countByMatchId(Integer matchId);
    long countByMatchIdAndStatus(Integer matchId, String status);
    List<MatchTask> findByMatch_Helper_IdAndStatusIn(Integer helperId, List<String> statuses);
    List<MatchTask> findByMatch_HelpRequest_Requester_IdAndStatusIn(Integer requesterId, List<String> statuses);
}
