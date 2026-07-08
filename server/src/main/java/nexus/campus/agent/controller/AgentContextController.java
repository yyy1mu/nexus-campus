package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.repository.AgentProfileRepository;
import nexus.campus.agent.repository.UserCapabilityRepository;
import nexus.campus.agent.repository.UserLlmSettingsRepository;
import nexus.campus.agent.service.AgentPreflightCatalog;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.service.WorkItemFeedService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus/me")
@RequiredArgsConstructor
public class AgentContextController {

    private final AgentProfileRepository profileRepo;
    private final UserCapabilityRepository capabilityRepo;
    private final UserLlmSettingsRepository llmRepo;
    private final WorkItemFeedService workItemFeed;
    private final AgentPreflightCatalog catalog;

    @GetMapping("/agent-context")
    public ApiResponse<Map<String, Object>> context(@AuthenticationPrincipal User user) {
        var profile = profileRepo.findByUser_Id(user.getId());
        var caps = capabilityRepo.findByUser_IdAndIsActiveTrue(user.getId());
        var llm = llmRepo.findById(user.getId());
        var items = workItemFeed.forUser(user.getId());

        boolean matching = profile.map(p -> p.isAllowAgentMatching()).orElse(false);
        boolean posting = profile.map(p -> p.isAllowAgentPosting()).orElse(false);

        var attrs = new LinkedHashMap<String, Object>();
        attrs.put("userId", user.getId());
        attrs.put("allowMatching", matching);
        attrs.put("allowPosting", posting);
        attrs.put("capabilityCount", (int) caps.stream().count());
        attrs.put("workQueueItemCount", items.size());
        attrs.put("availableActions", catalog.actionNames());
        attrs.put("endpoints", Map.of(
                "helpRequests", "/api/nexus/help-requests",
                "workItems", "/api/nexus/me/work-items",
                "agentProfile", "/api/nexus/me/agent-profile",
                "capabilities", "/api/nexus/capabilities",
                "forumDiscussions", "/api/nexus/forum/discussions"
        ));

        return ApiResponse.ok(attrs);
    }
}
