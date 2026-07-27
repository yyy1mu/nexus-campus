package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.dto.*;
import nexus.campus.help.entity.*;
import nexus.campus.help.repository.*;
import nexus.campus.help.service.HelpRequestService;
import nexus.campus.help.service.HelpMatchService;
import nexus.campus.agent.service.AgentNextActionEnricher;
import nexus.campus.security.authorization.AgentAuthorizationService;
import nexus.campus.common.logging.ActionLogService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class HelpRequestController {

    private final HelpRequestService helpRequestService;
    private final HelpRequestRepository helpRequestRepository;
    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchRepository matchRepository;
    private final HelpMatchMessageRepository messageRepository;
    private final HelpMatchService matchService;
    private final AgentAuthorizationService authorization;
    private final AgentWriteGuard guard;
    private final AgentNextActionEnricher enricher;
    private final ActionLogService actionLog;
    private final ObjectMapper objectMapper;

    // ── Help Requests ──

    @GetMapping("/help-requests")
    public ApiResponse<List<HelpRequestResponse>> list(
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(required = false) String status) {
        limit = Math.min(Math.max(limit, 1), 50);
        offset = Math.max(offset, 0);
        var results = status != null
                ? helpRequestRepository.findByStatusOrderByCreatedAtDesc(status)
                : helpRequestRepository.findAll();
        return ApiResponse.ok(results.stream().skip(offset).limit(limit)
                .map(this::toResponse).toList());
    }

    @GetMapping("/help-requests/{id}")
    public ApiResponse<HelpRequestResponse> show(@PathVariable Integer id) {
        return ApiResponse.ok(toResponse(helpRequestRepository.findById(id).orElseThrow()));
    }

    @PostMapping("/help-requests")
    public ApiResponse<HelpRequestResponse> create(
            @AuthenticationPrincipal User user, @RequestBody HelpRequestCreateRequest req) {
        guard.requireUser(user);
        if (!Boolean.TRUE.equals(req.getUserConfirmed()))
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "create help requests");

        var attrs = new LinkedHashMap<String, Object>();
        attrs.put("title", req.getTitle());
        attrs.put("summary", req.getSummary());
        attrs.put("content", req.getContent());
        attrs.put("categoryLabel", req.getCategoryLabel());
        attrs.put("neededLabels", req.getNeededLabels());
        attrs.put("urgency", req.getUrgency() != null ? req.getUrgency().name() : "normal");
        attrs.put("locationHint", req.getLocationHint());
        attrs.put("meetingSafetyState", req.getMeetingSafetyState() != null ? req.getMeetingSafetyState().name() : "not_arranged");
        attrs.put("agentContext", req.getAgentContext());
        var hreq = helpRequestService.create(user.getId(), null, attrs);
        return ApiResponse.ok(toResponse(hreq));
    }

    @PatchMapping("/help-requests/{id}")
    public ApiResponse<HelpRequestResponse> update(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody HelpRequestUpdateRequest req) {
        var hreq = helpRequestRepository.findById(id).orElseThrow();
        guard.requireUser(user);
        if (!hreq.getRequester().getId().equals(user.getId()))
            throw ApiException.forbidden();
        if (!Boolean.TRUE.equals(req.getUserConfirmed()))
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "update help requests");

        var attrs = new HashMap<String, Object>();
        if (req.getStatus() != null) attrs.put("status", req.getStatus().name());
        if (req.getSummary() != null) attrs.put("summary", req.getSummary());
        if (req.getNeededLabels() != null) attrs.put("neededLabels", req.getNeededLabels());
        if (req.getLocationHint() != null) attrs.put("locationHint", req.getLocationHint());
        if (req.getMeetingSafetyState() != null) attrs.put("meetingSafetyState", req.getMeetingSafetyState().name());
        if (req.getAgentContext() != null) attrs.put("agentContext", req.getAgentContext());
        attrs.put("userConfirmed", req.getUserConfirmed());
        var updated = helpRequestService.update(id, user.getId(), attrs);
        return ApiResponse.ok(toResponse(updated));
    }

    // ── Dispatches ──

    @GetMapping("/help-requests/{id}/dispatches")
    public ApiResponse<List<DispatchResponse>> dispatches(@PathVariable Integer id,
                                                           @AuthenticationPrincipal User user) {
        guard.requireUser(user);
        var req = helpRequestRepository.findById(id).orElseThrow();
        return ApiResponse.ok(dispatchRepository.findByHelpRequestIdOrderByCreatedAtDesc(id)
                .stream()
                .filter(d -> req.getRequester().getId().equals(user.getId()) || d.getHelper().getId().equals(user.getId()))
                .map(this::toDispatchResponse).toList());
    }

    // ── Matches ──

    @GetMapping("/help-requests/{id}/matches")
    public ApiResponse<List<MatchResponse>> matches(@PathVariable Integer id,
                                                     @AuthenticationPrincipal User user) {
        guard.requireUser(user);
        var req = helpRequestRepository.findById(id).orElseThrow();
        return ApiResponse.ok(matchRepository.findByHelpRequestIdOrderByCreatedAtDesc(id)
                .stream()
                .filter(m -> req.getRequester().getId().equals(user.getId()) || m.getHelper().getId().equals(user.getId()))
                .map(this::toMatchResponse).toList());
    }

    @PostMapping("/help-requests/{id}/matches")
    public ApiResponse<MatchResponse> offerMatch(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "offer help");

        String msg = (String) body.get("message");
        String hint = (String) body.get("meetingHint");
        String safety = (String) body.getOrDefault("meetingSafetyState", "not_arranged");
        var match = matchService.offer(id, user.getId(), msg, hint, safety);
        return ApiResponse.ok(toMatchResponse(match));
    }

    @PatchMapping("/matches/{id}")
    public ApiResponse<MatchResponse> updateMatch(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "update match");

        String newStatus = (String) body.get("status");
        String hint = (String) body.get("meetingHint");
        String safety = (String) body.get("meetingSafetyState");
        var match = matchService.updateStatus(id, user.getId(), newStatus, hint, safety);
        return ApiResponse.ok(toMatchResponse(match));
    }

    // ── Messages ──

    @GetMapping("/matches/{id}/messages")
    public ApiResponse<List<MatchMessageResponse>> messages(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestParam(required = false) Integer afterId,
            @RequestParam(defaultValue = "200") int limit) {
        guard.requireUser(user);
        var match = matchRepository.findById(id).orElseThrow();
        assertMatchParticipant(match, user.getId());
        int capped = Math.min(Math.max(limit, 1), 500);
        var list = afterId != null && afterId > 0
                ? messageRepository.findByMatchIdAndIdGreaterThanOrderByIdAsc(id, afterId)
                : messageRepository.findByMatchIdOrderByCreatedAtAsc(id);
        return ApiResponse.ok(list.stream().limit(capped)
                .map(this::toMessageResponse).toList());
    }

    @PostMapping("/matches/{id}/messages")
    public ApiResponse<MatchMessageResponse> sendMessage(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "send message");

        String content = (String) body.get("content");
        String clientRequestId = (String) body.get("clientRequestId");
        HelpMatchMessage msg;
        try {
            msg = matchService.sendMessage(id, user.getId(), content,
                    (String) body.get("agentContext"),
                    (String) body.get("kind"),
                    clientRequestId);
        } catch (org.springframework.dao.DataIntegrityViolationException conflict) {
            // Concurrent duplicate send: return the record the winner created.
            msg = matchService.messageReplay(id, user.getId(), clientRequestId)
                    .orElseThrow(() -> conflict);
        }
        return ApiResponse.ok(toMessageResponse(msg));
    }

    private MatchMessageResponse toMessageResponse(HelpMatchMessage m) {
        return MatchMessageResponse.builder()
                .id(m.getId()).matchId(m.getMatch().getId())
                .userId(m.getUser().getId()).content(m.getContent())
                .kind(m.getKind())
                .createdAt(m.getCreatedAt()).build();
    }

    // ── Serialization helpers ──

    private HelpRequestResponse toResponse(HelpRequest r) {
        return HelpRequestResponse.builder()
                .id(r.getId()).requesterUserId(r.getRequester().getId())
                .status(r.getStatus()).categoryLabel(r.getCategoryLabel())
                .summary(r.getSummary()).locationHint(r.getLocationHint())
                .meetingSafetyState(r.getMeetingSafetyState())
                .neededLabels(parseLabels(r.getNeededLabels()))
                .discussionId(r.getDiscussionId())
                .nextActions(enricher.buildRequestNextActions(r.getId()))
                .createdAt(r.getCreatedAt()).updatedAt(r.getUpdatedAt())
                .closedAt(r.getClosedAt())
                .build();
    }

    private List<String> parseLabels(String value) {
        if (value == null || value.isBlank()) return List.of();
        try {
            return objectMapper.readValue(value, new TypeReference<List<String>>() {});
        } catch (Exception ignored) {
            String trimmed = value.trim();
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                trimmed = trimmed.substring(1, trimmed.length() - 1);
            }
            if (trimmed.isBlank()) return List.of();
            return Arrays.stream(trimmed.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .toList();
        }
    }

    private void assertMatchParticipant(HelpMatch match, Integer userId) {
        var req = helpRequestRepository.findById(match.getHelpRequest().getId()).orElseThrow();
        boolean isRequester = req.getRequester().getId().equals(userId);
        boolean isHelper = match.getHelper().getId().equals(userId);
        if (!isRequester && !isHelper) throw ApiException.forbidden();
    }

    private DispatchResponse toDispatchResponse(HelpDispatch d) {
        return DispatchResponse.builder()
                .id(d.getId()).helpRequestId(d.getHelpRequest().getId())
                .requesterUserId(d.getRequester().getId())
                .helperUserId(d.getHelper().getId())
                .matchId(d.getMatch() != null ? d.getMatch().getId() : null)
                .status(d.getStatus()).message(d.getMessage())
                .rationale(d.getRationale()).responseMessage(d.getResponseMessage())
                .meetingHint(d.getMeetingHint()).meetingSafetyState(d.getMeetingSafetyState())
                .expiresAt(d.getExpiresAt()).respondedAt(d.getRespondedAt())
                .createdAt(d.getCreatedAt()).updatedAt(d.getUpdatedAt())
                .build();
    }

    private MatchResponse toMatchResponse(HelpMatch m) {
        return MatchResponse.builder()
                .id(m.getId()).helpRequestId(m.getHelpRequest().getId())
                .helperUserId(m.getHelper().getId())
                .status(m.getStatus()).message(m.getMessage())
                .meetingHint(m.getMeetingHint()).meetingSafetyState(m.getMeetingSafetyState())
                .collaborationState(m.getCollabState()).batonRole(m.getBatonRole())
                .createdAt(m.getCreatedAt()).acceptedAt(m.getAcceptedAt())
                .completedAt(m.getCompletedAt()).build();
    }
}
