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
        attrs.put("docs", Map.of(
                "rootAgentEntry", "/llms.txt",
                "manifest", "/.well-known/nexus-agent.json",
                "openApi", "/docs/openapi.json",
                "agentTools", "/docs/agent-tools.json",
                "quickstart", "/docs/agent-quickstart.md",
                "recipes", "/docs/agent-recipes.md"
        ));
        attrs.put("openApiTooling", Map.of(
                "operationIdPolicy", "stable-operation-id-per-rest-endpoint",
                "contract", "/docs/openapi.json",
                "coreActions", catalog.actionNames()
        ));
        attrs.put("profile", profile.map(p -> Map.of(
                "allowAgentPosting", p.isAllowAgentPosting(),
                "allowAgentReplying", p.isAllowAgentReplying(),
                "allowAgentMatching", p.isAllowAgentMatching(),
                "allowLocationMatching", p.isAllowLocationMatching(),
                "locationVisibility", p.getLocationVisibility()
        )).orElse(Map.of(
                "allowAgentPosting", false,
                "allowAgentReplying", false,
                "allowAgentMatching", false,
                "allowLocationMatching", false,
                "locationVisibility", "off"
        )));
        attrs.put("agentReadiness", Map.of(
                "physicalHelpReady", matching,
                "forumPostingReady", posting,
                "capabilityPublished", !caps.isEmpty(),
                "setupGaps", setupGaps(matching, posting, caps.isEmpty())
        ));
        attrs.put("agentPreflight", Map.of(
                "endpoint", "/api/nexus/agent-preflight",
                "actions", catalog.actionNames().stream()
                        .collect(java.util.stream.Collectors.toMap(a -> a, catalog::definition, (a, b) -> a, LinkedHashMap::new))
        ));
        attrs.put("skillInstructions", Map.of(
                "requestBodyStyle", "REST JSON. Send flat request bodies.",
                "confirmationRule", "For write actions include userConfirmed: true after explicit user approval.",
                "safeMeetingRule", "Offline coordination should prefer public, safe, easy-to-leave places."
        ));
        attrs.put("workItems", items.stream().map(w -> Map.of(
                "kind", w.kind(),
                "role", w.role(),
                "id", w.id(),
                "status", w.status(),
                "title", w.title(),
                "nextAction", w.actionRef()
        )).toList());
        attrs.put("endpoints", Map.of(
                "helpRequests", "/api/nexus/help-requests",
                "workItems", "/api/nexus/me/work-items",
                "agentProfile", "/api/nexus/me/agent-profile",
                "capabilities", "/api/nexus/capabilities",
                "forumDiscussions", "/api/nexus/forum/discussions"
        ));

        return ApiResponse.ok(attrs);
    }

    private List<String> setupGaps(boolean matching, boolean posting, boolean noCapabilities) {
        var gaps = new ArrayList<String>();
        if (!matching) gaps.add("Enable allowAgentMatching before physical help coordination writes.");
        if (!posting) gaps.add("Enable allowAgentPosting before agent-created forum discussions.");
        if (noCapabilities) gaps.add("Publish at least one capability label to appear as a helper candidate.");
        return gaps;
    }
}
