package nexus.campus.help.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import nexus.campus.agent.service.AgentNextActionEnricher;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.help.entity.*;
import nexus.campus.help.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

/**
 * Collaboration workspace attached to an accepted match: shared task list,
 * human decision gates, deliverable handoff, and an append-only event
 * timeline that lets both agents resume after interruption.
 *
 * All writes are participant-only. Creation endpoints accept an optional
 * clientRequestId; replays with the same id return the original row instead
 * of duplicating work.
 */
@Service
@RequiredArgsConstructor
public class MatchCollaborationService {

    public static final Set<String> ROLES = Set.of("requester", "helper");
    public static final Set<String> TASK_STATUSES = Set.of("todo", "doing", "blocked", "done");
    public static final Set<String> COLLAB_STATES = Set.of("active", "paused");

    private final HelpMatchRepository matchRepository;
    private final MatchTaskRepository taskRepository;
    private final MatchDecisionRepository decisionRepository;
    private final MatchDeliverableRepository deliverableRepository;
    private final MatchEventRepository eventRepository;
    private final MatchEventRecorder events;
    private final AgentNextActionEnricher enricher;
    private final PayloadValidator v;
    private final ObjectMapper objectMapper;

    // ── Workspace ──

    @Transactional(readOnly = true)
    public Map<String, Object> workspace(Integer matchId, Integer userId) {
        var match = participantMatch(matchId, userId);
        String role = roleOf(match, userId);

        var tasks = taskRepository.findByMatchIdOrderByOrderIndexAscIdAsc(matchId)
                .stream().map(this::taskMap).toList();
        var decisions = decisionRepository.findByMatchIdOrderByCreatedAtAscIdAsc(matchId)
                .stream().map(this::decisionMap).toList();
        var deliverables = deliverableRepository.findByMatchIdOrderByCreatedAtAscIdAsc(matchId)
                .stream().map(this::deliverableMap).toList();
        var recent = eventRepository.findTop50ByMatchIdOrderByIdDesc(matchId);
        Collections.reverse(recent);

        long tasksTotal = tasks.size();
        long tasksDone = tasks.stream().filter(t -> "done".equals(t.get("status"))).count();
        boolean deliverableAccepted = deliverables.stream()
                .anyMatch(d -> "accepted".equals(d.get("status")));

        var attention = new LinkedHashMap<String, Object>();
        attention.put("openDecisionsForYou", decisions.stream()
                .filter(d -> "open".equals(d.get("status")) && role.equals(d.get("assignedRole"))).count());
        attention.put("deliverablesAwaitingYourReview", deliverables.stream()
                .filter(d -> "submitted".equals(d.get("status")) && !role.equals(d.get("submitterRole"))).count());
        attention.put("yourOpenTasks", tasks.stream()
                .filter(t -> role.equals(t.get("ownerRole"))
                        && Set.of("todo", "doing", "blocked").contains((String) t.get("status"))).count());
        attention.put("batonWithYou", role.equals(match.getBatonRole()));

        var result = new LinkedHashMap<String, Object>();
        result.put("matchId", match.getId());
        result.put("helpRequestId", match.getHelpRequest().getId());
        result.put("helpRequestSummary", match.getHelpRequest().getSummary());
        result.put("matchStatus", match.getStatus());
        result.put("collaborationState", match.getCollabState());
        result.put("batonRole", match.getBatonRole());
        result.put("viewerRole", role);
        result.put("requesterUserId", match.getHelpRequest().getRequester().getId());
        result.put("helperUserId", match.getHelper().getId());
        result.put("counterpartUserId", "requester".equals(role)
                ? match.getHelper().getId() : match.getHelpRequest().getRequester().getId());
        result.put("progress", Map.of(
                "tasksDone", tasksDone,
                "tasksTotal", tasksTotal,
                "deliverableAccepted", deliverableAccepted));
        result.put("attention", attention);
        result.put("tasks", tasks);
        result.put("decisions", decisions);
        result.put("deliverables", deliverables);
        result.put("events", recent.stream().map(this::eventMap).toList());
        result.put("lastEventId", recent.isEmpty() ? 0 : recent.get(recent.size() - 1).getId());
        result.put("nextActions", enricher.buildMatchNextActions(matchId, role, match.getStatus()));
        result.put("sync", Map.of(
                "eventsEndpoint", "/api/nexus/matches/" + matchId + "/events?afterId=<lastEventId>",
                "messagesEndpoint", "/api/nexus/matches/" + matchId + "/messages?afterId=<lastMessageId>",
                "hint", "Poll events with afterId to resume after interruption; replay writes with the same clientRequestId are returned, not duplicated."));
        return result;
    }

    @Transactional
    public Map<String, Object> updateWorkspace(Integer matchId, Integer userId, Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        String role = roleOf(match, userId);
        requireAccepted(match);

        boolean changed = false;
        if (attrs.containsKey("collaborationState")) {
            String state = v.oneOf(attrs, "collaborationState", COLLAB_STATES, match.getCollabState());
            if (!state.equals(match.getCollabState())) {
                match.setCollabState(state);
                String note = v.string(attrs, "note", 300, false);
                events.record(match, userId, role,
                        "paused".equals(state) ? "workspace.paused" : "workspace.resumed",
                        "match", match.getId(),
                        ("paused".equals(state) ? "协作已暂停" : "协作已恢复")
                                + (note != null ? "：" + note : ""));
                changed = true;
            }
        }
        if (attrs.containsKey("baton")) {
            String baton = v.oneOf(attrs, "baton",
                    Set.of("requester", "helper", "none"),
                    match.getBatonRole() == null ? "none" : match.getBatonRole());
            String newBaton = "none".equals(baton) ? null : baton;
            if (!Objects.equals(newBaton, match.getBatonRole())) {
                match.setBatonRole(newBaton);
                String note = v.string(attrs, "note", 300, false);
                events.record(match, userId, role, "baton.passed", "match", match.getId(),
                        newBaton == null ? "接力棒已清除"
                                : "接力棒交给" + roleLabel(newBaton) + (note != null ? "：" + note : ""));
                changed = true;
            }
        }
        if (changed) matchRepository.save(match);
        return workspace(matchId, userId);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> eventsAfter(Integer matchId, Integer userId, Integer afterId, int limit) {
        participantMatch(matchId, userId);
        limit = Math.min(Math.max(limit, 1), 200);
        var list = afterId != null && afterId > 0
                ? eventRepository.findByMatchIdAndIdGreaterThanOrderByIdAsc(matchId, afterId)
                : eventRepository.findByMatchIdOrderByIdAsc(matchId);
        return list.stream().limit(limit).map(this::eventMap).toList();
    }

    // ── Tasks ──

    @Transactional
    public Map<String, Object> createTask(Integer matchId, Integer userId, Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        String role = roleOf(match, userId);

        // Replay check comes before pause/baton gating: retrying a request
        // that already succeeded must return the original record even if the
        // workspace state has moved on since.
        String clientRequestId = v.string(attrs, "clientRequestId", 80, false);
        if (clientRequestId != null) {
            var existing = taskRepository.findByMatchIdAndClientRequestId(matchId, clientRequestId);
            if (existing.isPresent()) return taskMap(existing.get());
        }
        assertCreationAllowed(match, role);

        var task = new MatchTask();
        task.setMatch(match);
        var creator = new User();
        creator.setId(userId);
        task.setCreatedBy(creator);
        task.setOwnerRole(v.oneOf(attrs, "ownerRole", ROLES, role));
        task.setTitle(v.string(attrs, "title", 160, true));
        task.setNote(v.string(attrs, "note", 2000, false));
        task.setStatus("todo");
        task.setOrderIndex((int) ((taskRepository.countByMatchId(matchId) + 1) * 10));
        task.setClientRequestId(clientRequestId);
        task = taskRepository.save(task);

        events.record(match, userId, role, "task.created", "task", task.getId(),
                "新任务（" + roleLabel(task.getOwnerRole()) + "）：" + task.getTitle());
        return taskMap(task);
    }

    @Transactional
    public Map<String, Object> updateTask(Integer matchId, Integer taskId, Integer userId,
                                          Map<String, Object> attrs) {
        var match = activeParticipantMatch(matchId, userId);
        String role = roleOf(match, userId);
        var task = taskRepository.findByIdAndMatchId(taskId, matchId)
                .orElseThrow(() -> ApiException.notFound("task", taskId));

        var changes = new ArrayList<String>();
        if (attrs.containsKey("status")) {
            String newStatus = v.oneOf(attrs, "status", TASK_STATUSES, task.getStatus());
            if (!newStatus.equals(task.getStatus())) {
                // Only the owning side advances a task; hand it over first if needed.
                if (!role.equals(task.getOwnerRole())) {
                    throw ApiException.forbidden();
                }
                if ("blocked".equals(newStatus)) {
                    String reason = v.string(attrs, "blockedReason", 500, true);
                    task.setBlockedReason(reason);
                    changes.add("受阻：" + reason);
                } else {
                    task.setBlockedReason(null);
                    changes.add("状态 " + task.getStatus() + " → " + newStatus);
                }
                task.setStatus(newStatus);
                task.setDoneAt("done".equals(newStatus) ? LocalDateTime.now() : null);
            }
        }
        if (attrs.containsKey("title")) {
            task.setTitle(v.string(attrs, "title", 160, true));
            changes.add("标题更新");
        }
        if (attrs.containsKey("note")) task.setNote(v.string(attrs, "note", 2000, false));
        if (attrs.containsKey("ownerRole")) {
            String owner = v.oneOf(attrs, "ownerRole", ROLES, task.getOwnerRole());
            if (!owner.equals(task.getOwnerRole())) {
                task.setOwnerRole(owner);
                changes.add("移交给" + roleLabel(owner));
            }
        }
        if (attrs.get("orderIndex") instanceof Number n) task.setOrderIndex(n.intValue());
        task = taskRepository.save(task);

        if (!changes.isEmpty()) {
            events.record(match, userId, role, "task.updated", "task", task.getId(),
                    "任务「" + task.getTitle() + "」" + String.join("；", changes));
        }
        return taskMap(task);
    }

    // ── Decisions (human gates) ──

    @Transactional
    public Map<String, Object> openDecision(Integer matchId, Integer userId, Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        String role = roleOf(match, userId);

        String clientRequestId = v.string(attrs, "clientRequestId", 80, false);
        if (clientRequestId != null) {
            var existing = decisionRepository.findByMatchIdAndClientRequestId(matchId, clientRequestId);
            if (existing.isPresent()) return decisionMap(existing.get());
        }
        assertCreationAllowed(match, role);

        // A decision gate is a cross-party checkpoint: the raiser asks the
        // OTHER side's human. An agent consulting its own human does that
        // locally and does not need a workspace gate — allowing self-assigned
        // gates would let one identity open and immediately "resolve" them.
        String assignedRole = v.oneOf(attrs, "assignedRole", ROLES, counterpart(role));
        if (assignedRole.equals(role)) {
            throw ApiException.badRequest("assignedRole",
                    "assignedRole must be the counterpart; a participant cannot open a decision gate for their own side.");
        }

        var decision = new MatchDecision();
        decision.setMatch(match);
        var raiser = new User();
        raiser.setId(userId);
        decision.setRaisedBy(raiser);
        decision.setRaisedByRole(role);
        decision.setAssignedRole(assignedRole);
        decision.setTitle(v.string(attrs, "title", 200, true));
        decision.setContext(v.string(attrs, "context", 4000, false));
        decision.setOptionsJson(encodeOptions(attrs.get("options")));
        decision.setClientRequestId(clientRequestId);
        decision = decisionRepository.save(decision);

        events.record(match, userId, role, "decision.opened", "decision", decision.getId(),
                "等待" + roleLabel(decision.getAssignedRole()) + "决策：" + decision.getTitle());
        return decisionMap(decision);
    }

    @Transactional
    public Map<String, Object> resolveDecision(Integer matchId, Integer decisionId, Integer userId,
                                               Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        String role = roleOf(match, userId);
        var decision = decisionRepository.findByIdAndMatchId(decisionId, matchId)
                .orElseThrow(() -> ApiException.notFound("decision", decisionId));

        String action = v.oneOf(attrs, "action", Set.of("decide", "cancel"), "decide");

        if ("cancel".equals(action)) {
            if ("cancelled".equals(decision.getStatus())) return decisionMap(decision);
            if (!"open".equals(decision.getStatus())) {
                throw ApiException.badRequest("action", "This decision has already been resolved.");
            }
            if (!role.equals(decision.getRaisedByRole())) {
                // Only the side that raised the gate may withdraw it; the
                // assigned side resolves it by deciding.
                throw ApiException.forbidden();
            }
            decision.setStatus("cancelled");
            decision.setDecisionNote(v.string(attrs, "note", 1000, false));
            decision = decisionRepository.save(decision);
            events.record(match, userId, role, "decision.cancelled", "decision", decision.getId(),
                    "决策已撤销：" + decision.getTitle());
            return decisionMap(decision);
        }

        String optionKey = v.string(attrs, "optionKey", 80, true);
        if ("decided".equals(decision.getStatus())) {
            // Idempotent replay of the same choice returns the decided record.
            if (optionKey.equals(decision.getDecidedOptionKey())) return decisionMap(decision);
            throw ApiException.badRequest("optionKey",
                    "This decision was already resolved with option '" + decision.getDecidedOptionKey() + "'.");
        }
        if (!"open".equals(decision.getStatus())) {
            throw ApiException.badRequest("action", "This decision is no longer open.");
        }
        if (!role.equals(decision.getAssignedRole())) {
            throw ApiException.forbidden();
        }
        if (parseOptions(decision.getOptionsJson()).stream()
                .noneMatch(o -> optionKey.equals(o.get("key")))) {
            throw ApiException.badRequest("optionKey", "optionKey must match one of the offered options.");
        }

        decision.setStatus("decided");
        decision.setDecidedOptionKey(optionKey);
        decision.setDecisionNote(v.string(attrs, "note", 1000, false));
        var decider = new User();
        decider.setId(userId);
        decision.setDecidedBy(decider);
        decision.setDecidedAt(LocalDateTime.now());
        decision = decisionRepository.save(decision);

        events.record(match, userId, role, "decision.decided", "decision", decision.getId(),
                "决策「" + decision.getTitle() + "」已选定：" + optionKey
                        + (decision.getDecisionNote() != null ? "（" + decision.getDecisionNote() + "）" : ""));
        return decisionMap(decision);
    }

    // ── Deliverables ──

    @Transactional
    public Map<String, Object> submitDeliverable(Integer matchId, Integer userId, Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        String role = roleOf(match, userId);

        String clientRequestId = v.string(attrs, "clientRequestId", 80, false);
        if (clientRequestId != null) {
            var existing = deliverableRepository.findByMatchIdAndClientRequestId(matchId, clientRequestId);
            if (existing.isPresent()) return deliverableMap(existing.get());
        }
        assertCreationAllowed(match, role);

        var deliverable = new MatchDeliverable();
        deliverable.setMatch(match);
        var submitter = new User();
        submitter.setId(userId);
        deliverable.setSubmittedBy(submitter);
        deliverable.setSubmitterRole(role);
        deliverable.setTitle(v.string(attrs, "title", 200, true));
        deliverable.setDescription(v.string(attrs, "description", 4000, false));
        deliverable.setAccessHint(v.string(attrs, "accessHint", 500, false));
        deliverable.setChecksum(v.string(attrs, "checksum", 128, false));
        deliverable.setLicenseNote(v.string(attrs, "licenseNote", 500, false));
        deliverable.setClientRequestId(clientRequestId);
        deliverable = deliverableRepository.save(deliverable);

        events.record(match, userId, role, "deliverable.submitted", "deliverable", deliverable.getId(),
                roleLabel(role) + "提交交付物：" + deliverable.getTitle()
                        + "，等待" + roleLabel(counterpart(role)) + "验收");
        return deliverableMap(deliverable);
    }

    @Transactional
    public Map<String, Object> reviewDeliverable(Integer matchId, Integer deliverableId, Integer userId,
                                                 Map<String, Object> attrs) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        String role = roleOf(match, userId);
        var deliverable = deliverableRepository.findByIdAndMatchId(deliverableId, matchId)
                .orElseThrow(() -> ApiException.notFound("deliverable", deliverableId));

        String action = v.oneOf(attrs, "action", Set.of("accept", "reject", "withdraw"), "accept");

        if ("withdraw".equals(action)) {
            if ("withdrawn".equals(deliverable.getStatus())) return deliverableMap(deliverable);
            if (!role.equals(deliverable.getSubmitterRole())) throw ApiException.forbidden();
            if (!"submitted".equals(deliverable.getStatus())) {
                throw ApiException.badRequest("action", "Only a pending deliverable can be withdrawn.");
            }
            deliverable.setStatus("withdrawn");
            deliverable = deliverableRepository.save(deliverable);
            events.record(match, userId, role, "deliverable.withdrawn", "deliverable", deliverable.getId(),
                    "交付物已撤回：" + deliverable.getTitle());
            return deliverableMap(deliverable);
        }

        if (role.equals(deliverable.getSubmitterRole())) {
            // The submitter cannot accept or reject their own deliverable.
            throw ApiException.forbidden();
        }
        String expected = "accept".equals(action) ? "accepted" : "rejected";
        if (expected.equals(deliverable.getStatus())) return deliverableMap(deliverable);
        if (!"submitted".equals(deliverable.getStatus())) {
            throw ApiException.badRequest("action", "This deliverable has already been reviewed.");
        }
        String note = v.string(attrs, "reviewNote", 1000, "reject".equals(action));

        deliverable.setStatus(expected);
        deliverable.setReviewNote(note);
        var reviewer = new User();
        reviewer.setId(userId);
        deliverable.setReviewedBy(reviewer);
        deliverable.setReviewedAt(LocalDateTime.now());
        deliverable = deliverableRepository.save(deliverable);

        events.record(match, userId, role,
                "accept".equals(action) ? "deliverable.accepted" : "deliverable.rejected",
                "deliverable", deliverable.getId(),
                "accept".equals(action)
                        ? "交付物已验收：" + deliverable.getTitle()
                        : "交付物被退回：" + deliverable.getTitle() + "（" + note + "）");
        return deliverableMap(deliverable);
    }

    // ── Idempotent replay lookups ──
    // Used by controllers when a concurrent duplicate create hits the
    // (match_id, client_request_id) unique constraint: the losing request
    // re-reads and returns the record the winning request created.

    @Transactional(readOnly = true)
    public Optional<Map<String, Object>> taskReplay(Integer matchId, Integer userId, String clientRequestId) {
        participantMatch(matchId, userId);
        return replayLookup(clientRequestId,
                id -> taskRepository.findByMatchIdAndClientRequestId(matchId, id).map(this::taskMap));
    }

    @Transactional(readOnly = true)
    public Optional<Map<String, Object>> decisionReplay(Integer matchId, Integer userId, String clientRequestId) {
        participantMatch(matchId, userId);
        return replayLookup(clientRequestId,
                id -> decisionRepository.findByMatchIdAndClientRequestId(matchId, id).map(this::decisionMap));
    }

    @Transactional(readOnly = true)
    public Optional<Map<String, Object>> deliverableReplay(Integer matchId, Integer userId, String clientRequestId) {
        participantMatch(matchId, userId);
        return replayLookup(clientRequestId,
                id -> deliverableRepository.findByMatchIdAndClientRequestId(matchId, id).map(this::deliverableMap));
    }

    private Optional<Map<String, Object>> replayLookup(
            String clientRequestId,
            java.util.function.Function<String, Optional<Map<String, Object>>> finder) {
        if (clientRequestId == null || clientRequestId.isBlank()) return Optional.empty();
        return finder.apply(clientRequestId.trim());
    }

    // ── Shared guards ──

    HelpMatch participantMatch(Integer matchId, Integer userId) {
        var match = matchRepository.findById(matchId)
                .orElseThrow(() -> ApiException.notFound("match", matchId));
        boolean requester = match.getHelpRequest().getRequester().getId().equals(userId);
        boolean helper = match.getHelper().getId().equals(userId);
        if (!requester && !helper) throw ApiException.forbidden();
        return match;
    }

    private HelpMatch activeParticipantMatch(Integer matchId, Integer userId) {
        var match = participantMatch(matchId, userId);
        requireAccepted(match);
        if ("paused".equals(match.getCollabState())) {
            throw ApiException.badRequest("collaborationState",
                    "Collaboration is paused by a participant. Resume it before pushing new work.");
        }
        return match;
    }

    /**
     * Guard for work-creation writes (tasks, decisions, deliverables): the
     * workspace must not be paused AND, when the baton is set, must be held
     * by the actor. Taking the baton is always possible via PATCH /workspace —
     * it is an explicit, evented act, which is the point: no silent
     * interleaving. Runs after the clientRequestId replay check so retries of
     * already-successful requests still return the original record.
     */
    private void assertCreationAllowed(HelpMatch match, String role) {
        if ("paused".equals(match.getCollabState())) {
            throw ApiException.badRequest("collaborationState",
                    "Collaboration is paused by a participant. Resume it before pushing new work.");
        }
        if (match.getBatonRole() != null && !match.getBatonRole().equals(role)) {
            throw ApiException.badRequest("baton",
                    "The baton is with the counterpart. Take it first via PATCH /workspace {\"baton\":\"" + role + "\"} or wait for the handoff.");
        }
    }

    private void requireAccepted(HelpMatch match) {
        if (!"accepted".equals(match.getStatus())) {
            throw ApiException.badRequest("status",
                    "The collaboration workspace is only available in accepted matches.");
        }
    }

    String roleOf(HelpMatch match, Integer userId) {
        return match.getHelpRequest().getRequester().getId().equals(userId) ? "requester" : "helper";
    }

    private String counterpart(String role) {
        return "requester".equals(role) ? "helper" : "requester";
    }

    private String roleLabel(String role) {
        return "requester".equals(role) ? "求助方" : "帮助方";
    }

    // ── Options encoding ──

    private String encodeOptions(Object raw) {
        if (!(raw instanceof List<?> list) || list.size() < 2 || list.size() > 5) {
            throw ApiException.badRequest("options", "options must list 2 to 5 choices.");
        }
        var options = new ArrayList<Map<String, String>>();
        var keys = new HashSet<String>();
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> map)) {
                throw ApiException.badRequest("options", "Each option needs a key and a label.");
            }
            String key = trimmed(map.get("key"), 80);
            String label = trimmed(map.get("label"), 200);
            if (key == null || label == null || !keys.add(key)) {
                throw ApiException.badRequest("options",
                        "Each option needs a unique key and a non-empty label.");
            }
            var option = new LinkedHashMap<String, String>();
            option.put("key", key);
            option.put("label", label);
            String note = trimmed(map.get("note"), 300);
            if (note != null) option.put("note", note);
            options.add(option);
        }
        try {
            return objectMapper.writeValueAsString(options);
        } catch (Exception e) {
            throw ApiException.badRequest("options", "options could not be encoded.");
        }
    }

    private List<Map<String, String>> parseOptions(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<List<Map<String, String>>>() {});
        } catch (Exception e) {
            return List.of();
        }
    }

    private String trimmed(Object value, int max) {
        if (value == null) return null;
        String s = value.toString().trim();
        if (s.isEmpty()) return null;
        return s.length() > max ? s.substring(0, max) : s;
    }

    // ── Serialization ──

    Map<String, Object> taskMap(MatchTask t) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", t.getId());
        m.put("matchId", t.getMatch().getId());
        m.put("title", t.getTitle());
        m.put("note", t.getNote());
        m.put("status", t.getStatus());
        m.put("ownerRole", t.getOwnerRole());
        m.put("blockedReason", t.getBlockedReason());
        m.put("orderIndex", t.getOrderIndex());
        m.put("createdByUserId", t.getCreatedBy().getId());
        m.put("createdAt", t.getCreatedAt());
        m.put("updatedAt", t.getUpdatedAt());
        m.put("doneAt", t.getDoneAt());
        return m;
    }

    Map<String, Object> decisionMap(MatchDecision d) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", d.getId());
        m.put("matchId", d.getMatch().getId());
        m.put("title", d.getTitle());
        m.put("context", d.getContext());
        m.put("options", parseOptions(d.getOptionsJson()));
        m.put("status", d.getStatus());
        m.put("assignedRole", d.getAssignedRole());
        m.put("raisedByRole", d.getRaisedByRole());
        m.put("raisedByUserId", d.getRaisedBy().getId());
        m.put("decidedOptionKey", d.getDecidedOptionKey());
        m.put("decisionNote", d.getDecisionNote());
        m.put("decidedByUserId", d.getDecidedBy() != null ? d.getDecidedBy().getId() : null);
        m.put("decidedAt", d.getDecidedAt());
        m.put("createdAt", d.getCreatedAt());
        return m;
    }

    Map<String, Object> deliverableMap(MatchDeliverable d) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", d.getId());
        m.put("matchId", d.getMatch().getId());
        m.put("title", d.getTitle());
        m.put("description", d.getDescription());
        m.put("accessHint", d.getAccessHint());
        m.put("checksum", d.getChecksum());
        m.put("licenseNote", d.getLicenseNote());
        m.put("status", d.getStatus());
        m.put("submitterRole", d.getSubmitterRole());
        m.put("submittedByUserId", d.getSubmittedBy().getId());
        m.put("reviewNote", d.getReviewNote());
        m.put("reviewedByUserId", d.getReviewedBy() != null ? d.getReviewedBy().getId() : null);
        m.put("reviewedAt", d.getReviewedAt());
        m.put("createdAt", d.getCreatedAt());
        return m;
    }

    Map<String, Object> eventMap(MatchEvent e) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", e.getId());
        m.put("matchId", e.getMatch().getId());
        m.put("eventType", e.getEventType());
        m.put("actorUserId", e.getActor() != null ? e.getActor().getId() : null);
        m.put("actorRole", e.getActorRole());
        m.put("refType", e.getRefType());
        m.put("refId", e.getRefId());
        m.put("summary", e.getSummary());
        m.put("createdAt", e.getCreatedAt());
        return m;
    }
}
