package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.repository.AgentProfileRepository;
import nexus.campus.common.entity.User;
import nexus.campus.agent.service.AgentPreflightCatalog;
import nexus.campus.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class AgentPreflightController {

    private final AgentPreflightCatalog catalog;
    private final AgentProfileRepository profileRepository;

    @GetMapping("/agent-health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.ok(Map.of(
            "status", "ok",
            "availableActions", catalog.actionNames(),
            "docs", Map.of(
                "openApi", "/docs/openapi.json",
                "agentTools", "/docs/agent-tools.json",
                "manifest", "/.well-known/nexus-agent.json"
            )
        ));
    }

    @PostMapping("/agent-preflight")
    public ApiResponse<Map<String, Object>> preflight(
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        String action = (String) body.get("action");
        if (!catalog.hasAction(action))
            return ApiResponse.ok(Map.of("allowed", false, "reason", "unknown action"));
        var def = new LinkedHashMap<>(catalog.definition(action));
        def.put("action", action);
        var blockers = new ArrayList<Map<String, Object>>();
        if (Boolean.TRUE.equals(def.get("requiresConfirmation"))
                && !Boolean.TRUE.equals(body.get("userConfirmed"))) {
            blockers.add(Map.of("field", "userConfirmed", "message", "Confirmation required."));
        }
        var profile = profileRepository.findByUser_Id(user.getId());
        @SuppressWarnings("unchecked")
        var permissions = (List<String>) def.getOrDefault("permissions", List.of());
        for (String permission : permissions) {
            boolean ok = profile.map(p -> switch (permission) {
                case "allowAgentPosting" -> p.isAllowAgentPosting();
                case "allowAgentReplying" -> p.isAllowAgentReplying();
                case "allowAgentMatching" -> p.isAllowAgentMatching();
                case "allowLocationMatching" -> p.isAllowLocationMatching();
                default -> false;
            }).orElse(false);
            if (!ok) {
                blockers.add(Map.of("field", permission,
                        "message", "Enable " + permission + " in /api/nexus/me/agent-profile."));
            }
        }
        def.put("allowed", blockers.isEmpty());
        def.put("blockers", blockers);
        def.put("target", body.get("target"));
        def.put("proposed", body.get("proposed"));
        return ApiResponse.ok(def);
    }
}
