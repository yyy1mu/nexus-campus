package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
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

    @PostMapping("/help-requests/{id}/dispatches")
    public ApiResponse<DispatchResponse> create(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data"))
                .getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");
        auth.assertMatchingAllowed(user.getId(), "dispatch help requests");
        var d = matchService.createDispatch(id, user.getId(),
                ((Number) attrs.get("helperUserId")).intValue(), attrs);
        return ApiResponse.ok(toResponse(d));
    }

    @PatchMapping("/dispatches/{id}")
    public ApiResponse<DispatchResponse> update(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data"))
                .getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");
        auth.assertMatchingAllowed(user.getId(), "respond to dispatch");

        var d = dispatchRepo.findById(id).orElseThrow();
        boolean isHelper = d.getHelper().getId().equals(user.getId());
        if (!isHelper) throw ApiException.forbidden();

        if (attrs.containsKey("status")) d.setStatus((String) attrs.get("status"));
        if (attrs.containsKey("responseMessage")) d.setResponseMessage((String) attrs.get("responseMessage"));
        if (attrs.containsKey("meetingSafetyState")) d.setMeetingSafetyState((String) attrs.get("meetingSafetyState"));
        d = dispatchRepo.save(d);
        return ApiResponse.ok(toResponse(d));
    }

    @GetMapping("/help-requests/{id}/candidates")
    public ApiResponse<List<Map<String, Object>>> candidates(@PathVariable Integer id) {
        var req = helpRequestRepo.findById(id).orElseThrow();
        var caps = capRepo.findByIsActiveTrue();
        var candidates = new ArrayList<Map<String, Object>>();
        for (var c : caps) {
            candidates.add(Map.of(
                    "userId", c.getUser().getId(),
                    "label", c.getLabel(), "name", c.getName(),
                    "summary", c.getSummary()));
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
}
