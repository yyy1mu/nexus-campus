package nexus.campus.forum.controller;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.forum.repository.*;
import nexus.campus.forum.service.ForumService;
import nexus.campus.security.authorization.AgentAuthorizationService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class ForumController {

    private final ForumService forumService;
    private final DiscussionRepository discussionRepo;
    private final PostRepository postRepo;

    @GetMapping("/forum/discussions")
    public ApiResponse<List<Map<String, Object>>> list(
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int offset) {
        return ApiResponse.ok(discussionRepo.findAll().stream().skip(offset).limit(limit)
                .map(d -> Map.<String,Object>of("id", d.getId(), "title", d.getTitle(),
                        "commentCount", d.getCommentCount(), "createdAt", d.getCreatedAt())).toList());
    }

    @GetMapping("/forum/discussions/{id}")
    public ApiResponse<Map<String, Object>> show(@PathVariable Integer id) {
        var d = discussionRepo.findById(id).orElseThrow();
        var attrs = new LinkedHashMap<String, Object>();
        attrs.put("id", d.getId()); attrs.put("title", d.getTitle());
        attrs.put("createdAt", d.getCreatedAt());
        return ApiResponse.ok(attrs);
    }

    @PostMapping("/forum/discussions")
    public ApiResponse<Map<String, Object>> create(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).get("attributes");
        String title = (String) attrs.get("title");
        String content = (String) attrs.get("content");
        var disc = forumService.createDiscussion(user, title, content, List.of(), request.getRemoteAddr());
        return ApiResponse.ok(Map.of("id", disc.getId(), "title", disc.getTitle()));
    }

    @GetMapping("/me/discussions")
    public ApiResponse<List<Map<String, Object>>> myDiscussions(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(discussionRepo.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(d -> Map.<String,Object>of("id", d.getId(), "title", d.getTitle())).toList());
    }
}
