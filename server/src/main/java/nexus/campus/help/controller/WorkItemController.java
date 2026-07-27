package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.repository.AgentActionLogRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.repository.*;
import nexus.campus.help.service.WorkItemFeedService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus/me")
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WorkItemController {

    private final WorkItemFeedService workItemFeed;
    private final HelpRequestRepository helpRequestRepository;
    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchRepository matchRepository;
    private final AgentActionLogRepository logRepository;

    @GetMapping("/work-items")
    public ApiResponse<List<Map<String, Object>>> workItems(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var w : workItemFeed.forUser(user.getId())) {
            var item = new LinkedHashMap<String, Object>();
            item.put("kind", w.kind());
            item.put("role", w.role());
            item.put("id", w.id());
            item.put("status", w.status());
            item.put("title", w.title());
            item.put("relatedUserId", w.relatedUserId());
            item.put("nextAction", w.actionRef());
            items.add(item);
        }
        return ApiResponse.ok(items);
    }

    @GetMapping("/help-requests")
    public ApiResponse<List<Map<String, Object>>> myHelpRequests(@AuthenticationPrincipal User user) {
        var items = new ArrayList<Map<String, Object>>();
        for (var r : helpRequestRepository.findByRequesterIdOrderByCreatedAtDesc(user.getId())) {
            var m = new LinkedHashMap<String, Object>();
            m.put("id", r.getId()); m.put("status", r.getStatus());
            m.put("summary", r.getSummary()); m.put("createdAt", r.getCreatedAt());
            items.add(m);
        }
        return ApiResponse.ok(items);
    }

    @GetMapping("/dispatches")
    public ApiResponse<List<Map<String, Object>>> myDispatches(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(dispatchRepository.findByHelperIdOrderByCreatedAtDesc(user.getId()).stream()
                .map(d -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", d.getId());
                    m.put("status", d.getStatus());
                    m.put("helpRequestId", d.getHelpRequest().getId());
                    m.put("requesterUserId", d.getRequester().getId());
                    m.put("helperUserId", d.getHelper().getId());
                    m.put("matchId", d.getMatch() != null ? d.getMatch().getId() : null);
                    m.put("message", d.getMessage());
                    m.put("rationale", d.getRationale());
                    m.put("responseMessage", d.getResponseMessage());
                    m.put("expiresAt", d.getExpiresAt());
                    m.put("createdAt", d.getCreatedAt());
                    return m;
                }).toList());
    }

    @GetMapping("/matches")
    public ApiResponse<List<Map<String, Object>>> myMatches(@AuthenticationPrincipal User user) {
        var matches = new ArrayList<Map<String, Object>>();
        matchRepository.findByHelperIdOrderByCreatedAtDesc(user.getId())
                .forEach(m -> matches.add(matchMap(m, "helper")));
        matchRepository.findByHelpRequest_Requester_IdOrderByCreatedAtDesc(user.getId())
                .forEach(m -> matches.add(matchMap(m, "requester")));
        return ApiResponse.ok(matches);
    }

    @GetMapping("/action-logs")
    public ApiResponse<List<Map<String, Object>>> actionLogs(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(logRepository.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .limit(20).map(l -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", l.getId());
                    m.put("actionType", l.getActionType());
                    m.put("targetType", l.getTargetType());
                    m.put("targetId", l.getTargetId());
                    m.put("status", l.getStatus());
                    m.put("userConfirmed", l.isUserConfirmed());
                    m.put("inputSummary", l.getInputSummary());
                    m.put("outputSummary", l.getOutputSummary());
                    m.put("ipAddress", l.getIpAddress());
                    m.put("createdAt", l.getCreatedAt());
                    return m;
                }).toList());
    }

    private Map<String, Object> matchMap(nexus.campus.help.entity.HelpMatch match, String role) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", match.getId());
        m.put("status", match.getStatus());
        m.put("role", role);
        m.put("helpRequestId", match.getHelpRequest().getId());
        m.put("requesterUserId", match.getHelpRequest().getRequester().getId());
        m.put("helperUserId", match.getHelper().getId());
        m.put("message", match.getMessage());
        m.put("meetingHint", match.getMeetingHint());
        m.put("meetingSafetyState", match.getMeetingSafetyState());
        m.put("createdAt", match.getCreatedAt());
        m.put("acceptedAt", match.getAcceptedAt());
        m.put("completedAt", match.getCompletedAt());
        return m;
    }
}
