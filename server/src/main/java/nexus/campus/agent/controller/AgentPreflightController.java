package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.service.AgentPreflightCatalog;
import nexus.campus.common.response.ApiResponse;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class AgentPreflightController {

    private final AgentPreflightCatalog catalog;

    @GetMapping("/agent-health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.ok(Map.of("status", "ok", "availableActions", catalog.actionNames()));
    }

    @PostMapping("/agent-preflight")
    public ApiResponse<Map<String, Object>> preflight(@RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).get("attributes");
        String action = (String) attrs.get("action");
        if (!catalog.hasAction(action))
            return ApiResponse.ok(Map.of("allowed", false, "reason", "unknown action"));
        var def = new LinkedHashMap<>(catalog.definition(action));
        def.put("action", action);
        return ApiResponse.ok(def);
    }
}
