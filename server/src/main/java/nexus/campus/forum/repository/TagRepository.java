package nexus.campus.forum.repository;

import nexus.campus.forum.entity.Tag;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TagRepository extends JpaRepository<Tag, Integer> {
    List<Tag> findBySlugIn(List<String> slugs);
}
