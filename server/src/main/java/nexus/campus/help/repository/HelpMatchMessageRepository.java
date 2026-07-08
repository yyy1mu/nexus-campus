package nexus.campus.help.repository;

import nexus.campus.help.entity.HelpMatchMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface HelpMatchMessageRepository extends JpaRepository<HelpMatchMessage, Integer> {
    List<HelpMatchMessage> findByMatchIdOrderByCreatedAtAsc(Integer matchId);
}
