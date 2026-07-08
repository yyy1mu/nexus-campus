package nexus.campus.forum.repository;

import nexus.campus.forum.entity.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PostRepository extends JpaRepository<Post, Integer> {
    List<Post> findByDiscussionIdOrderByNumberAsc(Integer discussionId);
    List<Post> findByUser_IdOrderByCreatedAtDesc(Integer userId);
}
