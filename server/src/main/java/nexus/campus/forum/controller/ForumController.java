package nexus.campus.forum.controller;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.forum.repository.*;
import nexus.campus.forum.service.ForumService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class ForumController {

    private final ForumService forumService;
    private final DiscussionRepository discussionRepo;
    private final PostRepository postRepo;
    private final TagRepository tagRepo;
    private final AgentWriteGuard guard;

    @GetMapping("/forum/discussions")
    @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> list(
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) String q) {
        var stream = discussionRepo.findAll().stream()
                .filter(d -> d.getHiddenAt() == null)
                .filter(d -> q == null || q.isBlank() || d.getTitle().toLowerCase().contains(q.toLowerCase()))
                .sorted(Comparator.comparing(nexus.campus.forum.entity.Discussion::getLastPostedAt,
                        Comparator.nullsLast(Comparator.reverseOrder())));
        return ApiResponse.ok(stream.skip(offset).limit(Math.min(Math.max(limit, 1), 50))
                .map(this::discussionSummary).toList());
    }

    @GetMapping("/forum/discussions/{id}")
    @Transactional(readOnly = true)
    public ApiResponse<Map<String, Object>> show(@PathVariable Integer id) {
        var d = discussionRepo.findById(id).orElseThrow();
        return ApiResponse.ok(discussionDetail(d));
    }

    @GetMapping("/forum/tags")
    @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> tags() {
        return ApiResponse.ok(tagRepo.findAll().stream()
                .filter(t -> !t.isHidden())
                .map(this::tagMap).toList());
    }

    @PostMapping("/forum/discussions")
    @Transactional
    public ApiResponse<Map<String, Object>> create(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        guard.requirePosting(user, body, "create forum discussions");
        String title = (String) body.get("title");
        String content = (String) body.get("content");
        var disc = forumService.createDiscussion(user, title, content, forumService.resolveTagIds(body), request.getRemoteAddr());
        return ApiResponse.ok(discussionDetail(disc));
    }

    @GetMapping("/me/discussions")
    @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> myDiscussions(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(discussionRepo.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(this::discussionSummary).toList());
    }

    @GetMapping("/me/posts")
    @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> myPosts(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(postRepo.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(this::postMap).toList());
    }

    @PostMapping("/forum/discussions/{id}/posts")
    @Transactional
    public ApiResponse<Map<String, Object>> reply(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body, HttpServletRequest request) {
        guard.requireReplying(user, body, "reply to forum discussions");
        String content = (String) body.get("content");
        var post = forumService.reply(id, user, content, request.getRemoteAddr());
        return ApiResponse.ok(postMap(post));
    }

    @PatchMapping("/forum/posts/{id}")
    @Transactional
    public ApiResponse<Map<String, Object>> editPost(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireReplying(user, body, "edit forum posts");
        String content = (String) body.get("content");
        var post = forumService.editPost(id, user, content);
        return ApiResponse.ok(postMap(post));
    }

    @DeleteMapping("/forum/posts/{id}")
    public ApiResponse<Void> deletePost(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody(required = false) Map<String, Object> body) {
        guard.requireReplying(user, body != null ? body : Map.of(), "hide forum posts");
        forumService.hidePost(id, user);
        return ApiResponse.ok(null);
    }

    private Map<String, Object> discussionSummary(nexus.campus.forum.entity.Discussion d) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", d.getId());
        m.put("title", d.getTitle());
        m.put("slug", d.getSlug());
        m.put("author", d.getUser().getUsername());
        m.put("commentCount", d.getCommentCount());
        m.put("createdAt", d.getCreatedAt());
        m.put("lastPostedAt", d.getLastPostedAt());
        m.put("tags", d.getTags() != null ? d.getTags().stream().map(this::tagMap).toList() : List.of());
        var first = d.getFirstPost();
        m.put("excerpt", first != null && first.getContent() != null
                ? first.getContent().replaceAll("\\s+", " ").strip() : "");
        return m;
    }

    private Map<String, Object> discussionDetail(nexus.campus.forum.entity.Discussion d) {
        var m = new LinkedHashMap<>(discussionSummary(d));
        m.put("posts", postRepo.findByDiscussionIdOrderByNumberAsc(d.getId()).stream().map(this::postMap).toList());
        return m;
    }

    private Map<String, Object> postMap(nexus.campus.forum.entity.Post p) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", p.getId());
        m.put("discussionId", p.getDiscussion().getId());
        m.put("number", p.getNumber());
        m.put("userId", p.getUser().getId());
        m.put("author", p.getUser().getUsername());
        m.put("content", p.getContent());
        m.put("createdAt", p.getCreatedAt());
        m.put("editedAt", p.getEditedAt());
        m.put("hiddenAt", p.getHiddenAt());
        return m;
    }

    private Map<String, Object> tagMap(nexus.campus.forum.entity.Tag t) {
        return Map.of("id", t.getId(), "slug", t.getSlug(), "name", t.getName(),
                "color", t.getColor() != null ? t.getColor() : "",
                "description", t.getDescription() != null ? t.getDescription() : "");
    }
}
