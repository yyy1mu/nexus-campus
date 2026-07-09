package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.entity.UserCapability;
import nexus.campus.agent.repository.UserCapabilityRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class CapabilityController {

    private final UserCapabilityRepository repo;
    private final AgentWriteGuard guard;

    @GetMapping("/capabilities")
    public ApiResponse<List<Map<String, Object>>> list(
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) String label) {
        var caps = label != null ? repo.findByLabelAndIsActiveTrue(label) : repo.findByIsActiveTrue();
        return ApiResponse.ok(caps.stream().skip(offset).limit(limit).map(this::toMap).toList());
    }

    @GetMapping("/capability-labels")
    public ApiResponse<List<Map<String, Object>>> labels(@RequestParam(defaultValue = "20") int limit) {
        var caps = repo.findByIsActiveTrue();
        Map<String, Map<String, Object>> labels = new LinkedHashMap<>();
        for (var c : caps) {
            labels.computeIfAbsent(c.getLabel(), k -> new LinkedHashMap<>(Map.of(
                    "label", k, "name", c.getName(), "helperCount", 0, "capabilityCount", 0)));
            labels.get(c.getLabel()).put("capabilityCount",
                    (Integer) labels.get(c.getLabel()).get("capabilityCount") + 1);
        }
        for (var e : labels.entrySet()) {
            long count = caps.stream().filter(c -> c.getLabel().equals(e.getKey()))
                    .map(c -> c.getUser().getId()).distinct().count();
            e.getValue().put("helperCount", (int) count);
            e.getValue().put("reuseGuidance", "Reuse this exact label in neededLabels and capability search before creating a new label.");
            e.getValue().put("nextActions", List.of(
                    Map.of("name", "search_capabilities", "method", "GET",
                            "endpoint", "/api/nexus/capabilities?label=" + e.getKey()),
                    Map.of("name", "search_open_help_requests", "method", "GET",
                            "endpoint", "/api/nexus/help-requests?status=open")
            ));
        }
        return ApiResponse.ok(new ArrayList<>(labels.values()).stream().limit(limit).toList());
    }

    @GetMapping("/me/capabilities")
    public ApiResponse<List<Map<String, Object>>> my(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(repo.findByUser_IdAndIsActiveTrue(user.getId()).stream()
                .map(this::toMap).toList());
    }

    @PatchMapping("/me/capabilities")
    public ApiResponse<List<Map<String, Object>>> update(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);
        @SuppressWarnings("unchecked")
        var items = (List<Map<String, Object>>) body.get("capabilities");
        if (items == null) throw ApiException.badRequest("capabilities", "required");
        Set<String> seen = new LinkedHashSet<>();
        for (var item : items) {
            String lbl = ((String) item.getOrDefault("label", "")).trim().toLowerCase();
            if (lbl.isEmpty()) continue; seen.add(lbl);
            var cap = repo.findByUser_IdAndLabel(user.getId(), lbl).orElseGet(() -> {
                var c = new UserCapability(); c.setUser(user); c.setLabel(lbl); return c;
            });
            cap.setName((String) item.getOrDefault("name", lbl));
            cap.setSummary((String) item.get("summary"));
            cap.setAvailability((String) item.get("availability"));
            if (item.get("serviceRadiusM") instanceof Number n) cap.setServiceRadiusM(n.intValue());
            cap.setActive(!item.containsKey("isActive") || Boolean.TRUE.equals(item.get("isActive")));
            repo.save(cap);
        }
        repo.findByUser_IdAndIsActiveTrue(user.getId()).stream()
                .filter(c -> !seen.contains(c.getLabel()))
                .forEach(c -> { c.setActive(false); repo.save(c); });
        return my(user);
    }

    private Map<String, Object> toMap(UserCapability c) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", c.getId());
        m.put("userId", c.getUser().getId());
        m.put("label", c.getLabel());
        m.put("name", c.getName());
        m.put("summary", c.getSummary());
        m.put("availability", c.getAvailability());
        m.put("serviceRadiusM", c.getServiceRadiusM());
        m.put("isActive", c.isActive());
        m.put("createdAt", c.getCreatedAt());
        m.put("updatedAt", c.getUpdatedAt());
        return m;
    }
}
