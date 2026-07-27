package nexus.campus.help.repository;

import nexus.campus.help.entity.MatchEvent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MatchEventRepository extends JpaRepository<MatchEvent, Integer> {
    List<MatchEvent> findByMatchIdOrderByIdAsc(Integer matchId);
    List<MatchEvent> findByMatchIdAndIdGreaterThanOrderByIdAsc(Integer matchId, Integer afterId);
    List<MatchEvent> findTop50ByMatchIdOrderByIdDesc(Integer matchId);
}
