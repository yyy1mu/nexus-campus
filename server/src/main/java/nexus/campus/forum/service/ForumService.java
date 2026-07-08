package nexus.campus.forum.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.forum.entity.Discussion;
import nexus.campus.forum.entity.Post;
import nexus.campus.forum.entity.Tag;
import nexus.campus.forum.repository.DiscussionRepository;
import nexus.campus.forum.repository.PostRepository;
import nexus.campus.forum.repository.TagRepository;
import nexus.campus.common.entity.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@RequiredArgsConstructor
public class ForumService {

    private final DiscussionRepository discussionRepository;
    private final PostRepository postRepository;
    private final TagRepository tagRepository;

    public static final String AGENT_FOOTER = "\n\nPosted by Nexus Agent after explicit user confirmation.";

    @Transactional
    public Discussion createDiscussion(User actor, String title, String content, List<Integer> tagIds, String ipAddress) {
        var disc = new Discussion();
        disc.setTitle(title);
        disc.setUser(actor);
        disc.setSlug(slugify(title));
        disc.setCreatedAt(java.time.LocalDateTime.now());
        disc.setLastPostedAt(java.time.LocalDateTime.now());
        disc.setLastPostedUserId(actor.getId());

        if (tagIds != null && !tagIds.isEmpty()) {
            disc.setTags(tagRepository.findAllById(tagIds));
        }

        disc = discussionRepository.save(disc);

        var post = new Post();
        post.setDiscussion(disc);
        post.setNumber(1);
        post.setUser(actor);
        post.setContent(content + AGENT_FOOTER);
        post.setType("comment");
        post.setIpAddress(ipAddress);
        post = postRepository.save(post);

        disc.setFirstPost(post);
        return discussionRepository.save(disc);
    }

    @Transactional
    public Post reply(Integer discussionId, User actor, String content, String ipAddress) {
        var disc = discussionRepository.findById(discussionId).orElseThrow();

        int nextNumber = disc.getPosts() != null
                ? disc.getPosts().stream().mapToInt(Post::getNumber).max().orElse(0) + 1
                : disc.getCommentCount() + 1;

        var post = new Post();
        post.setDiscussion(disc);
        post.setNumber(nextNumber);
        post.setUser(actor);
        post.setContent(content + AGENT_FOOTER);
        post.setType("comment");
        post.setIpAddress(ipAddress);
        post = postRepository.save(post);

        disc.setCommentCount(disc.getCommentCount() + 1);
        disc.setLastPostedAt(java.time.LocalDateTime.now());
        disc.setLastPostedUserId(actor.getId());
        discussionRepository.save(disc);

        return post;
    }

    @Transactional
    public Post editPost(Integer postId, User actor, String content) {
        var post = postRepository.findById(postId).orElseThrow();
        if (!post.getUser().getId().equals(actor.getId())) {
            throw new RuntimeException("Permission denied");
        }
        post.setContent(content + "\n\nEdited by Nexus Agent after explicit user confirmation.");
        post.setEditedAt(java.time.LocalDateTime.now());
        return postRepository.save(post);
    }

    @Transactional
    public void hidePost(Integer postId, User actor) {
        var post = postRepository.findById(postId).orElseThrow();
        if (!post.getUser().getId().equals(actor.getId())) {
            throw new RuntimeException("Permission denied");
        }
        post.setHiddenAt(java.time.LocalDateTime.now());
        postRepository.save(post);
    }

    public List<Integer> resolveTagIds(Map<String, Object> attrs) {
        Object raw = attrs.get("tagIds");
        if (raw == null) raw = attrs.get("tags");
        if (raw == null) return List.of();

        List<String> slugs = new ArrayList<>();
        List<Integer> ids = new ArrayList<>();

        if (raw instanceof List<?> list) {
            for (Object item : list) {
                if (item instanceof Number n) ids.add(n.intValue());
                else slugs.add(item.toString().trim());
            }
        }

        if (!slugs.isEmpty()) {
            tagRepository.findBySlugIn(slugs).forEach(t -> ids.add(t.getId()));
        }

        return ids.stream().distinct().filter(i -> i > 0).limit(8).toList();
    }

    private String slugify(String title) {
        return title.toLowerCase().replaceAll("[^a-z0-9]+", "-")
                .replaceAll("^-|-$", "");
    }
}
