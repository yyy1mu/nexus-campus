package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.dto.DispatchResponse;
import nexus.campus.help.entity.HelpDispatch;
import nexus.campus.help.repository.*;
import nexus.campus.help.service.HelpMatchService;
import nexus.campus.agent.repository.UserCapabilityRepository;
import nexus.campus.agent.repository.AgentActionLogRepository;
import nexus.campus.security.authorization.AgentAuthorizationService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class DispatchController {

    private final HelpDispatchRepository dispatchRepo;
    private final HelpRequestRepository helpRequestRepo;
    private final UserCapabilityRepository capRepo;
    private final AgentActionLogRepository logRepo;
    private final HelpMatchService matchService;
    private final AgentAuthorizationService auth;
    private final AgentWriteGuard guard;
    private final ObjectMapper objectMapper;

    @PostMapping("/help-requests/{id}/dispatches")
    public ApiResponse<DispatchResponse> create(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "dispatch help requests");
        if (!(body.get("helperUserId") instanceof Number helperUserId)) {
            throw ApiException.badRequest("helperUserId", "helperUserId is required.");
        }
        var d = matchService.createDispatch(id, user.getId(),
                helperUserId.intValue(), body);
        return ApiResponse.ok(toResponse(d));
    }

    @PatchMapping("/dispatches/{id}")
    public ApiResponse<DispatchResponse> update(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "respond to dispatch");
        var d = matchService.respondToDispatch(id, user.getId(), body);
        return ApiResponse.ok(toResponse(d));
    }

    @GetMapping("/help-requests/{id}/candidates")
    public ApiResponse<List<Map<String, Object>>> candidates(@PathVariable Integer id) {
        var req = helpRequestRepo.findById(id).orElseThrow();
        var caps = capRepo.findByIsActiveTrue();
        var candidates = new ArrayList<Map<String, Object>>();
        for (var c : caps) {
            var item = new LinkedHashMap<String, Object>();
            item.put("userId", c.getUser().getId());
            item.put("label", c.getLabel());
            item.put("name", c.getName());
            item.put("summary", c.getSummary());
            item.put("availability", c.getAvailability());
            item.put("serviceRadiusM", c.getServiceRadiusM());
            item.put("matchedLabels", List.of(c.getLabel()));
            item.put("neededLabels", parseLabels(req.getNeededLabels()));
            item.put("recommendation", "verify_then_dispatch");
            item.put("dispatchRationaleTemplate", "Helper has active capability label " + c.getLabel() + ".");
            candidates.add(item);
        }
        return ApiResponse.ok(candidates);
    }

    private DispatchResponse toResponse(HelpDispatch d) {
        return DispatchResponse.builder()
                .id(d.getId()).helpRequestId(d.getHelpRequest().getId())
                .requesterUserId(d.getRequester().getId()).helperUserId(d.getHelper().getId())
                .matchId(d.getMatch() != null ? d.getMatch().getId() : null)
                .status(d.getStatus()).message(d.getMessage())
                .rationale(d.getRationale()).responseMessage(d.getResponseMessage())
                .meetingHint(d.getMeetingHint()).meetingSafetyState(d.getMeetingSafetyState())
                .expiresAt(d.getExpiresAt()).respondedAt(d.getRespondedAt())
                .createdAt(d.getCreatedAt()).updatedAt(d.getUpdatedAt())
                .build();
    }

    private List<String> parseLabels(String value) {
        if (value == null || value.isBlank()) return List.of();
        try {
            return objectMapper.readValue(value, new TypeReference<List<String>>() {});
        } catch (Exception ignored) {
            return List.of(value);
        }
    }
}
