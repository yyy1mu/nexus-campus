package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.dto.*;
import nexus.campus.help.entity.*;
import nexus.campus.help.repository.*;
import nexus.campus.help.service.HelpRequestService;
import nexus.campus.help.service.HelpMatchService;
import nexus.campus.agent.service.AgentNextActionEnricher;
import nexus.campus.security.authorization.AgentAuthorizationService;
import nexus.campus.common.logging.ActionLogService;
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
    private final AgentNextActionEnricher enricher;
    private final ActionLogService actionLog;

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
        if (!Boolean.TRUE.equals(req.getUserConfirmed()))
            throw nexus.campus.common.exception.ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "create help requests");

        var attrs = Map.<String, Object>of(
            "title", req.getTitle(), "summary", req.getSummary(),
            "categoryLabel", Objects.requireNonNullElse(req.getCategoryLabel(), ""),
            "urgency", Objects.toString(req.getUrgency(), "normal")
        );
        var hreq = helpRequestService.create(user.getId(), null, attrs);
        return ApiResponse.ok(toResponse(hreq));
    }

    @PatchMapping("/help-requests/{id}")
    public ApiResponse<HelpRequestResponse> update(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody HelpRequestUpdateRequest req) {
        var hreq = helpRequestRepository.findById(id).orElseThrow();
        if (!hreq.getRequester().getId().equals(user.getId()))
            throw nexus.campus.common.exception.ApiException.forbidden();
        if (!Boolean.TRUE.equals(req.getUserConfirmed()))
            throw nexus.campus.common.exception.ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "update help requests");

        var attrs = new HashMap<String, Object>();
        if (req.getStatus() != null) attrs.put("status", req.getStatus().name());
        if (req.getSummary() != null) attrs.put("summary", req.getSummary());
        attrs.put("userConfirmed", req.getUserConfirmed());
        var updated = helpRequestService.update(id, user.getId(), attrs);
        return ApiResponse.ok(toResponse(updated));
    }

    // ── Dispatches ──

    @GetMapping("/help-requests/{id}/dispatches")
    public ApiResponse<List<DispatchResponse>> dispatches(@PathVariable Integer id) {
        return ApiResponse.ok(dispatchRepository.findByHelpRequestIdOrderByCreatedAtDesc(id)
                .stream().map(this::toDispatchResponse).toList());
    }

    // ── Matches ──

    @GetMapping("/help-requests/{id}/matches")
    public ApiResponse<List<MatchResponse>> matches(@PathVariable Integer id) {
        return ApiResponse.ok(matchRepository.findByHelpRequestIdOrderByCreatedAtDesc(id)
                .stream().map(this::toMatchResponse).toList());
    }

    @PostMapping("/help-requests/{id}/matches")
    public ApiResponse<MatchResponse> offerMatch(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw nexus.campus.common.exception.ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "offer help");

        String msg = (String) attrs.get("message");
        String hint = (String) attrs.get("meetingHint");
        String safety = (String) attrs.getOrDefault("meetingSafetyState", "not_arranged");
        var match = matchService.offer(id, user.getId(), msg, hint, safety);
        return ApiResponse.ok(toMatchResponse(match));
    }

    @PatchMapping("/matches/{id}")
    public ApiResponse<MatchResponse> updateMatch(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw nexus.campus.common.exception.ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "update match");

        String newStatus = (String) attrs.get("status");
        String hint = (String) attrs.get("meetingHint");
        String safety = (String) attrs.get("meetingSafetyState");
        var match = matchService.updateStatus(id, user.getId(), newStatus, hint, safety);
        return ApiResponse.ok(toMatchResponse(match));
    }

    // ── Messages ──

    @GetMapping("/matches/{id}/messages")
    public ApiResponse<List<MatchMessageResponse>> messages(@PathVariable Integer id) {
        return ApiResponse.ok(messageRepository.findByMatchIdOrderByCreatedAtAsc(id)
                .stream().map(m -> MatchMessageResponse.builder()
                    .id(m.getId()).matchId(m.getMatch().getId())
                    .userId(m.getUser().getId()).content(m.getContent())
                    .createdAt(m.getCreatedAt()).build()
                ).toList());
    }

    @PostMapping("/matches/{id}/messages")
    public ApiResponse<MatchMessageResponse> sendMessage(
            @PathVariable Integer id, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw nexus.campus.common.exception.ApiException.badRequest("userConfirmed", "Confirmation required.");
        authorization.assertMatchingAllowed(user.getId(), "send message");

        String content = (String) attrs.get("content");
        var msg = matchService.sendMessage(id, user.getId(), content, null);
        return ApiResponse.ok(MatchMessageResponse.builder()
                .id(msg.getId()).matchId(msg.getMatch().getId())
                .userId(msg.getUser().getId()).content(msg.getContent())
                .createdAt(msg.getCreatedAt()).build());
    }

    // ── Serialization helpers ──

    private HelpRequestResponse toResponse(HelpRequest r) {
        return HelpRequestResponse.builder()
                .id(r.getId()).requesterUserId(r.getRequester().getId())
                .status(r.getStatus()).categoryLabel(r.getCategoryLabel())
                .summary(r.getSummary()).locationHint(r.getLocationHint())
                .meetingSafetyState(r.getMeetingSafetyState())
                .neededLabels(r.getNeededLabels() != null ? List.of(r.getNeededLabels()) : List.of())
                .discussionId(r.getDiscussionId())
                .nextActions(enricher.buildRequestNextActions(r.getId()))
                .createdAt(r.getCreatedAt()).updatedAt(r.getUpdatedAt())
                .closedAt(r.getClosedAt())
                .build();
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
                .createdAt(m.getCreatedAt()).acceptedAt(m.getAcceptedAt())
                .completedAt(m.getCompletedAt()).build();
    }
}
