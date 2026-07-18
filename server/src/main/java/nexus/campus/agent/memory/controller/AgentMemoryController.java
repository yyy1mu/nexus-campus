package nexus.campus.agent.memory.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.memory.dto.*;
import nexus.campus.agent.memory.service.AgentMemoryService;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.logging.ActionLogService;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class AgentMemoryController {
    private final AgentMemoryService memoryService;
    private final ActionLogService actionLog;
    private final AgentWriteGuard guard;

    @GetMapping("/me/memories")
    public ApiResponse<List<AgentMemoryResponse>> list(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) String kind,
            @RequestParam(defaultValue = "active") String status,
            @RequestParam(required = false) String tags,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int offset) {
        guard.requireUser(user);
        List<String> tagList = tags == null || tags.isBlank()
                ? List.of() : Arrays.asList(tags.split(","));
        return ApiResponse.ok(memoryService.list(
                user.getId(), query, kind, status, tagList, limit, offset));
    }

    @GetMapping("/me/memories/{memoryId}")
    public ApiResponse<AgentMemoryResponse> show(
            @PathVariable Integer memoryId,
            @AuthenticationPrincipal User user) {
        guard.requireUser(user);
        return ApiResponse.ok(memoryService.get(user.getId(), memoryId));
    }

    @PostMapping("/me/memories/recall")
    public ApiResponse<List<AgentMemoryResponse>> recall(
            @AuthenticationPrincipal User user,
            @RequestBody AgentMemoryRecallRequest request) {
        guard.requireUser(user);
        return ApiResponse.ok(memoryService.recall(user.getId(), request));
    }

    @PostMapping("/me/memories")
    public ApiResponse<AgentMemoryResponse> create(
            @AuthenticationPrincipal User user,
            @RequestBody AgentMemoryWriteRequest request) {
        guard.requireConfirmedUser(user, confirmation(request.getUserConfirmed()));
        AgentMemoryResponse memory = memoryService.create(user.getId(), request);
        actionLog.log(user, "memory.create", "agent_memory", memory.getId(),
                summary(request), Map.of("memoryId", memory.getId()), null, true);
        return ApiResponse.ok(memory);
    }

    @PatchMapping("/me/memories/{memoryId}")
    public ApiResponse<AgentMemoryResponse> update(
            @PathVariable Integer memoryId,
            @AuthenticationPrincipal User user,
            @RequestBody AgentMemoryWriteRequest request) {
        guard.requireConfirmedUser(user, confirmation(request.getUserConfirmed()));
        AgentMemoryResponse memory = memoryService.update(user.getId(), memoryId, request);
        actionLog.log(user, "memory.update", "agent_memory", memoryId,
                summary(request), Map.of("memoryId", memoryId), null, true);
        return ApiResponse.ok(memory);
    }

    @DeleteMapping("/me/memories/{memoryId}")
    public ApiResponse<Map<String, Object>> delete(
            @PathVariable Integer memoryId,
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);
        memoryService.delete(user.getId(), memoryId);
        actionLog.log(user, "memory.delete", "agent_memory", memoryId,
                Map.of("userConfirmed", true), Map.of("deleted", true), null, true);
        return ApiResponse.ok(Map.of("memoryId", memoryId, "deleted", true));
    }

    @GetMapping("/matches/{matchId}/memory-shares")
    public ApiResponse<List<MatchMemoryShareResponse>> sharedContext(
            @PathVariable Integer matchId,
            @AuthenticationPrincipal User user) {
        guard.requireUser(user);
        return ApiResponse.ok(memoryService.sharedContext(user.getId(), matchId));
    }

    @PostMapping("/matches/{matchId}/memory-shares")
    public ApiResponse<List<MatchMemoryShareResponse>> share(
            @PathVariable Integer matchId,
            @AuthenticationPrincipal User user,
            @RequestBody MatchMemoryShareRequest request) {
        guard.requireMatching(
                user, confirmation(request.getUserConfirmed()), "share memory with a match");
        List<MatchMemoryShareResponse> shares =
                memoryService.share(user.getId(), matchId, request);
        actionLog.log(user, "memory_share.create", "help_match", matchId,
                Map.of(
                        "memoryIds", Optional.ofNullable(request.getMemoryIds()).orElse(List.of()),
                        "userConfirmed", true),
                Map.of("activeShareCount", shares.size()), null, true);
        return ApiResponse.ok(shares);
    }

    @PatchMapping("/matches/{matchId}/memory-shares/{shareId}")
    public ApiResponse<MatchMemoryShareResponse> revoke(
            @PathVariable Integer matchId,
            @PathVariable Integer shareId,
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);
        if (!Boolean.TRUE.equals(body.get("revoked"))) {
            throw ApiException.badRequest("revoked", "Set revoked to true.");
        }
        MatchMemoryShareResponse share =
                memoryService.revoke(user.getId(), matchId, shareId);
        actionLog.log(user, "memory_share.revoke", "memory_share", shareId,
                Map.of("matchId", matchId, "userConfirmed", true),
                Map.of("revoked", true), null, true);
        return ApiResponse.ok(share);
    }

    private Map<String, Object> confirmation(Object confirmed) {
        var attrs = new HashMap<String, Object>();
        attrs.put("userConfirmed", confirmed);
        return attrs;
    }

    private Map<String, Object> summary(AgentMemoryWriteRequest request) {
        var summary = new LinkedHashMap<String, Object>();
        if (request.getKind() != null) summary.put("kind", request.getKind());
        if (request.getTitle() != null) summary.put("title", request.getTitle());
        if (request.getContent() != null) summary.put("contentLength", request.getContent().length());
        if (request.getTags() != null) summary.put("tags", request.getTags());
        if (request.getSensitivity() != null) summary.put("sensitivity", request.getSensitivity());
        if (request.getSharePolicy() != null) summary.put("sharePolicy", request.getSharePolicy());
        summary.put("userConfirmed", true);
        return summary;
    }
}
