package nexus.campus.forum.repository;

import nexus.campus.forum.entity.Discussion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.List;

public interface DiscussionRepository extends JpaRepository<Discussion, Integer>,
        JpaSpecificationExecutor<Discussion> {
    List<Discussion> findByUser_IdOrderByCreatedAtDesc(Integer userId);
}
