package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.memory.service.AgentMemoryService;
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
    private final AgentMemoryService memoryService;

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
                "openApi", "/v3/api-docs",
                "agentTools", "/docs/agent-tools.json",
                "quickstart", "/docs/agent-quickstart.md",
                "recipes", "/docs/agent-recipes.md"
        ));
        attrs.put("openApiTooling", Map.of(
                "operationIdPolicy", "stable-operation-id-per-rest-endpoint",
                "contract", "/v3/api-docs",
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
        attrs.put("memory", memoryService.bootstrap(user.getId()));
        attrs.put("endpoints", Map.of(
                "helpRequests", "/api/nexus/help-requests",
                "workItems", "/api/nexus/me/work-items",
                "agentProfile", "/api/nexus/me/agent-profile",
                "memories", "/api/nexus/me/memories",
                "memoryRecall", "/api/nexus/me/memories/recall",
                "capabilities", "/api/nexus/capabilities",
                "forumDiscussions", "/api/nexus/forum/discussions",
                "matchWorkspace", "/api/nexus/matches/{id}/workspace",
                "matchEvents", "/api/nexus/matches/{id}/events?afterId=<lastEventId>"
        ));
        attrs.put("collaborationLoop", Map.of(
                "afterMatchAccepted", List.of(
                        "GET /api/nexus/matches/{id}/workspace to load shared tasks, decisions, deliverables, and events.",
                        "Poll GET /api/nexus/matches/{id}/events?afterId=<lastEventId> to sync instead of re-reading everything.",
                        "Plan with POST .../tasks (status changes are owner-side only); hand steps over with PATCH .../workspace {baton} — while set, only the holder creates new work.",
                        "Escalate real choices with POST .../decisions: assignedRole must be the counterpart, only their human decides, only the raiser cancels.",
                        "Deliver with POST .../deliverables; the counterpart reviews with PATCH .../deliverables/{id}. Only the requester completes the match, after all gates are resolved."),
                "reliability", "Send clientRequestId on creates; replays (including concurrent retries) return the original record instead of duplicating it.",
                "humanControl", "Deciding gates, reviewing deliverables, pause/resume, and baton moves require only userConfirmed — they work even when allowAgentMatching is off. A paused workspace rejects new tasks, decisions, and deliverables."
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
