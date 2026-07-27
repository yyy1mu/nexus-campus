package nexus.campus.help.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.logging.ActionLogService;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.help.service.MatchCollaborationService;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

@RestController
@RequestMapping("/api/nexus/matches/{matchId}")
@RequiredArgsConstructor
public class MatchWorkspaceController {

    private final MatchCollaborationService collaboration;
    private final AgentWriteGuard guard;
    private final ActionLogService actionLog;

    // ── Workspace snapshot & sync ──

    @GetMapping("/workspace")
    public ApiResponse<Map<String, Object>> workspace(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user) {
        guard.requireUser(user);
        return ApiResponse.ok(collaboration.workspace(matchId, user.getId()));
    }

    @PatchMapping("/workspace")
    public ApiResponse<Map<String, Object>> updateWorkspace(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        // Human control action: pause/resume/baton must stay available even
        // when the user has switched allowAgentMatching off.
        guard.requireConfirmedUser(user, body);
        var result = collaboration.updateWorkspace(matchId, user.getId(), body);
        actionLog.log(user, "match_workspace.update", "match", matchId,
                Map.of("collaborationState", String.valueOf(body.get("collaborationState")),
                       "baton", String.valueOf(body.get("baton"))),
                null, null, true);
        return ApiResponse.ok(result);
    }

    @GetMapping("/events")
    public ApiResponse<List<Map<String, Object>>> events(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user,
            @RequestParam(required = false) Integer afterId,
            @RequestParam(defaultValue = "100") int limit) {
        guard.requireUser(user);
        return ApiResponse.ok(collaboration.eventsAfter(matchId, user.getId(), afterId, limit));
    }

    // ── Tasks ──

    @PostMapping("/tasks")
    public ApiResponse<Map<String, Object>> createTask(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "create collaboration tasks");
        var result = idempotent(
                () -> collaboration.createTask(matchId, user.getId(), body),
                () -> collaboration.taskReplay(matchId, user.getId(), clientRequestId(body)));
        actionLog.log(user, "match_task.create", "match_task", (Integer) result.get("id"),
                Map.of("title", String.valueOf(body.get("title"))), null, null, true);
        return ApiResponse.ok(result);
    }

    @PatchMapping("/tasks/{taskId}")
    public ApiResponse<Map<String, Object>> updateTask(
            @PathVariable Integer matchId, @PathVariable Integer taskId,
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "update collaboration tasks");
        var result = collaboration.updateTask(matchId, taskId, user.getId(), body);
        actionLog.log(user, "match_task.update", "match_task", taskId,
                Map.of("status", String.valueOf(body.get("status"))), null, null, true);
        return ApiResponse.ok(result);
    }

    // ── Decisions ──

    @PostMapping("/decisions")
    public ApiResponse<Map<String, Object>> openDecision(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "open collaboration decisions");
        var result = idempotent(
                () -> collaboration.openDecision(matchId, user.getId(), body),
                () -> collaboration.decisionReplay(matchId, user.getId(), clientRequestId(body)));
        actionLog.log(user, "match_decision.create", "match_decision", (Integer) result.get("id"),
                Map.of("title", String.valueOf(body.get("title")),
                       "assignedRole", String.valueOf(body.get("assignedRole"))), null, null, true);
        return ApiResponse.ok(result);
    }

    @PatchMapping("/decisions/{decisionId}")
    public ApiResponse<Map<String, Object>> resolveDecision(
            @PathVariable Integer matchId, @PathVariable Integer decisionId,
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        // Human gate: deciding or withdrawing a decision is a human control
        // action and does not depend on the allowAgentMatching switch.
        guard.requireConfirmedUser(user, body);
        var result = collaboration.resolveDecision(matchId, decisionId, user.getId(), body);
        actionLog.log(user, "match_decision.resolve", "match_decision", decisionId,
                Map.of("action", String.valueOf(body.getOrDefault("action", "decide")),
                       "optionKey", String.valueOf(body.get("optionKey"))), null, null, true);
        return ApiResponse.ok(result);
    }

    // ── Deliverables ──

    @PostMapping("/deliverables")
    public ApiResponse<Map<String, Object>> submitDeliverable(
            @PathVariable Integer matchId, @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireMatching(user, body, "submit deliverables");
        var result = idempotent(
                () -> collaboration.submitDeliverable(matchId, user.getId(), body),
                () -> collaboration.deliverableReplay(matchId, user.getId(), clientRequestId(body)));
        actionLog.log(user, "match_deliverable.create", "match_deliverable", (Integer) result.get("id"),
                Map.of("title", String.valueOf(body.get("title"))), null, null, true);
        return ApiResponse.ok(result);
    }

    @PatchMapping("/deliverables/{deliverableId}")
    public ApiResponse<Map<String, Object>> reviewDeliverable(
            @PathVariable Integer matchId, @PathVariable Integer deliverableId,
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        // Human gate: reviewing a deliverable is a human control action and
        // does not depend on the allowAgentMatching switch.
        guard.requireConfirmedUser(user, body);
        var result = collaboration.reviewDeliverable(matchId, deliverableId, user.getId(), body);
        actionLog.log(user, "match_deliverable.review", "match_deliverable", deliverableId,
                Map.of("action", String.valueOf(body.getOrDefault("action", "accept"))), null, null, true);
        return ApiResponse.ok(result);
    }

    /**
     * Concurrent duplicate creates race past the pre-insert lookup and hit the
     * (match_id, client_request_id) unique constraint. The loser re-reads the
     * winner's record and returns it — the client sees the same 200 either way.
     */
    private Map<String, Object> idempotent(
            Supplier<Map<String, Object>> create,
            Supplier<Optional<Map<String, Object>>> replay) {
        try {
            return create.get();
        } catch (DataIntegrityViolationException conflict) {
            return replay.get().orElseThrow(() -> conflict);
        }
    }

    private String clientRequestId(Map<String, Object> body) {
        Object value = body.get("clientRequestId");
        return value == null ? null : value.toString();
    }
}
