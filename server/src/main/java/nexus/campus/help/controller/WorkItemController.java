package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.repository.*;
import nexus.campus.help.service.WorkItemFeedService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus/me")
@RequiredArgsConstructor
public class WorkItemController {

    private final WorkItemFeedService workItemFeed;
    private final HelpRequestRepository helpRequestRepository;
    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchRepository matchRepository;

    @GetMapping("/work-items")
    public ApiResponse<List<Map<String, Object>>> workItems(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var w : workItemFeed.forUser(user.getId())) {
            items.add(Map.of("kind", w.kind(), "role", w.role(), "id", w.id(),
                    "status", w.status(), "title", w.title()));
        }
        return ApiResponse.ok(items);
    }

    @GetMapping("/help-requests")
    public ApiResponse<List<Map<String, Object>>> myHelpRequests(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var r : helpRequestRepository.findByRequesterIdOrderByCreatedAtDesc(user.getId())) {
            var m = new LinkedHashMap<String, Object>();
            m.put("id", r.getId()); m.put("status", r.getStatus());
            m.put("summary", r.getSummary()); m.put("createdAt", r.getCreatedAt());
            items.add(m);
        }
        return ApiResponse.ok(items);
    }

    @GetMapping("/dispatches")
    public ApiResponse<List<Map<String, Object>>> myDispatches(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var d : dispatchRepository.findByHelperIdOrderByCreatedAtDesc(user.getId())) {
            items.add(Map.of("id", d.getId(), "status", d.getStatus(),
                    "helpRequestId", d.getHelpRequest().getId()));
        }
        return ApiResponse.ok(items);
    }

    @GetMapping("/matches")
    public ApiResponse<List<Map<String, Object>>> myMatches(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var m : matchRepository.findByHelperIdOrderByCreatedAtDesc(user.getId())) {
            items.add(Map.of("id", m.getId(), "status", m.getStatus(),
                    "helpRequestId", m.getHelpRequest().getId()));
        }
        return ApiResponse.ok(items);
    }
}
