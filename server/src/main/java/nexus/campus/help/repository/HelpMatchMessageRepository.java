package nexus.campus.help.repository;

import nexus.campus.help.entity.HelpMatchMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface HelpMatchMessageRepository extends JpaRepository<HelpMatchMessage, Integer> {
    List<HelpMatchMessage> findByMatchIdOrderByCreatedAtAsc(Integer matchId);
    List<HelpMatchMessage> findByMatchIdAndIdGreaterThanOrderByIdAsc(Integer matchId, Integer afterId);
    Optional<HelpMatchMessage> findByMatchIdAndClientRequestId(Integer matchId, String clientRequestId);
}
