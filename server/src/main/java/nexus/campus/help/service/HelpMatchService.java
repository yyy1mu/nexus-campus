package nexus.campus.help.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.help.entity.HelpDispatch;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.entity.HelpMatchMessage;
import nexus.campus.help.entity.HelpRequest;
import nexus.campus.help.repository.*;
import nexus.campus.common.entity.User;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.common.exception.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class HelpMatchService {

    private final HelpMatchRepository matchRepository;
    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchMessageRepository messageRepository;
    private final HelpRequestRepository helpRequestRepository;
    private final MatchDeliverableRepository deliverableRepository;
    private final MatchDecisionRepository decisionRepository;
    private final MatchEventRecorder events;
    private final PayloadValidator v;

    public static final java.util.Set<String> MESSAGE_KINDS =
            java.util.Set.of("chat", "update", "question", "handoff");

    @Transactional
    public HelpMatch offer(Integer helpRequestId, Integer helperId, String message, String meetingHint, String meetingSafetyState) {
        var req = helpRequestRepository.findById(helpRequestId).orElseThrow();
        if (req.getRequester().getId().equals(helperId)) {
            throw ApiException.badRequest("helperUserId", "Cannot offer help to own request.");
        }

        var existing = matchRepository.findByHelpRequestIdAndHelperId(helpRequestId, helperId);
        HelpMatch match = existing.orElseGet(() -> {
            var m = new HelpMatch();
            m.setHelpRequest(req);
            var helper = new User();
            helper.setId(helperId);
            m.setHelper(helper);
            return m;
        });

        if (existing.isPresent() && !"offered".equals(match.getStatus())) {
            throw ApiException.badRequest("status",
                    "This existing match is no longer open for a new offer.");
        }

        match.setStatus("offered");
        match.setMessage(message);
        match.setMeetingHint(meetingHint);
        match.setMeetingSafetyState(meetingSafetyState);
        match = matchRepository.save(match);

        if ("open".equals(req.getStatus())) {
            req.setStatus("matching");
            helpRequestRepository.save(req);
        }

        return match;
    }

    @Transactional
    public HelpMatch updateStatus(Integer matchId, Integer actorId, String newStatus,
                                   String meetingHint, String meetingSafetyState) {
        var match = matchRepository.findById(matchId).orElseThrow();
        var req = match.getHelpRequest();
        boolean isRequester = req.getRequester().getId().equals(actorId);
        boolean isHelper = match.getHelper().getId().equals(actorId);
        if (!isRequester && !isHelper) {
            throw ApiException.forbidden();
        }

        String prevStatus = match.getStatus();
        if (newStatus == null || newStatus.isBlank()) {
            throw ApiException.badRequest("status", "status is required.");
        }

        // Validate transition
        if (java.util.Set.of("declined", "cancelled", "completed").contains(prevStatus)
                && !newStatus.equals(prevStatus)) {
            throw ApiException.badRequest("status", "This match has already been resolved.");
        }

        if ("offered".equals(newStatus) && !"offered".equals(prevStatus)) {
            throw ApiException.badRequest("status", "Cannot move back to offered.");
        }

        Map<String, java.util.Set<String>> allowed = Map.of(
            "offered", java.util.Set.of("offered", "accepted", "declined", "cancelled"),
            "accepted", java.util.Set.of("accepted", "completed", "cancelled")
        );
        if (!allowed.getOrDefault(prevStatus, java.util.Set.of(prevStatus)).contains(newStatus)) {
            throw ApiException.badRequest("status",
                    "Cannot move from " + prevStatus + " to " + newStatus + ".");
        }

        // Role-based restrictions. Completion is the requester confirming the
        // help was actually delivered, so only the requester can set it; the
        // helper's exits are cancel or asking the requester to complete.
        if (java.util.Set.of("accepted", "declined", "completed").contains(newStatus) && !isRequester) {
            throw ApiException.forbidden();
        }
        if ("cancelled".equals(newStatus) && !isHelper && !isRequester) {
            throw ApiException.forbidden();
        }

        // Completion requires the collaboration to be settled: every decision
        // gate resolved (decided or withdrawn by its raiser) and no deliverable
        // still waiting for review. Nothing is silently auto-cancelled here.
        if ("completed".equals(newStatus) && !"completed".equals(prevStatus)) {
            if (!deliverableRepository.findByMatchIdAndStatus(matchId, "submitted").isEmpty()) {
                throw ApiException.badRequest("status",
                        "Review the pending deliverable (accept or reject) before completing this match.");
            }
            if (!decisionRepository.findByMatchIdAndStatus(matchId, "open").isEmpty()) {
                throw ApiException.badRequest("status",
                        "Resolve or cancel the open decision gates before completing this match.");
            }
        }

        match.setStatus(newStatus);
        if (meetingHint != null) match.setMeetingHint(meetingHint);
        if (meetingSafetyState != null) match.setMeetingSafetyState(meetingSafetyState);

        String actorRole = isRequester ? "requester" : "helper";
        if ("accepted".equals(newStatus) && match.getAcceptedAt() == null) {
            match.setAcceptedAt(LocalDateTime.now());
            req.setStatus("matched");
            req.setMeetingSafetyState(match.getMeetingSafetyState());
            helpRequestRepository.save(req);
            match = matchRepository.save(match);
            events.record(match, actorId, actorRole, "match.accepted", "match", match.getId(),
                    "匹配已接受，协作工作区已开启");
            return match;
        }
        if ("completed".equals(newStatus) && match.getCompletedAt() == null) {
            match.setCompletedAt(LocalDateTime.now());
            req.setStatus("closed");
            req.setClosedAt(LocalDateTime.now());
            helpRequestRepository.save(req);
            match = matchRepository.save(match);
            events.record(match, actorId, actorRole, "match.completed", "match", match.getId(),
                    "协作已完成，求助已关闭");
            return match;
        }
        if ("cancelled".equals(newStatus) && !"cancelled".equals(prevStatus)) {
            closeOpenDecisions(match, "match cancelled");
            match = matchRepository.save(match);
            events.record(match, actorId, actorRole, "match.cancelled", "match", match.getId(),
                    "协作已取消");
            return match;
        }

        return matchRepository.save(match);
    }

    /** Replay lookup for concurrent duplicate message creates. */
    @Transactional(readOnly = true)
    public java.util.Optional<HelpMatchMessage> messageReplay(
            Integer matchId, Integer userId, String clientRequestId) {
        if (clientRequestId == null || clientRequestId.isBlank()) return java.util.Optional.empty();
        var match = matchRepository.findById(matchId).orElseThrow();
        var req = match.getHelpRequest();
        if (!req.getRequester().getId().equals(userId) && !match.getHelper().getId().equals(userId)) {
            throw ApiException.forbidden();
        }
        return messageRepository.findByMatchIdAndClientRequestId(matchId, clientRequestId.trim());
    }

    private void closeOpenDecisions(HelpMatch match, String reason) {
        for (var decision : decisionRepository.findByMatchIdAndStatus(match.getId(), "open")) {
            decision.setStatus("cancelled");
            decision.setDecisionNote("Auto-cancelled: " + reason + ".");
            decisionRepository.save(decision);
        }
    }

    @Transactional
    public HelpDispatch createDispatch(Integer helpRequestId, Integer requesterId,
                                        Integer helperUserId, Map<String, Object> attrs) {
        var req = helpRequestRepository.findById(helpRequestId).orElseThrow();
        if (!req.getRequester().getId().equals(requesterId)) {
            throw ApiException.forbidden();
        }

        var existing = dispatchRepository.findByHelpRequestIdAndHelperId(helpRequestId, helperUserId);
        HelpDispatch dispatch = existing.orElseGet(() -> {
            var d = new HelpDispatch();
            d.setHelpRequest(req);
            var r = new User(); r.setId(requesterId); d.setRequester(r);
            var h = new User(); h.setId(helperUserId); d.setHelper(h);
            return d;
        });

        if (existing.isPresent() && "accepted".equals(dispatch.getStatus())) {
            throw ApiException.badRequest("helperUserId",
                    "This helper has already accepted the dispatch.");
        }

        dispatch.setStatus("pending");
        dispatch.setMessage(v.string(attrs, "message", 2000, false));
        dispatch.setRationale(v.string(attrs, "rationale", 2000, false));
        dispatch.setMeetingHint(v.string(attrs, "meetingHint", 255, false));
        dispatch.setMeetingSafetyState(v.oneOf(attrs, "meetingSafetyState",
                java.util.Set.of("not_arranged", "public_place_suggested", "public_place_confirmed"),
                "not_arranged"));
        dispatch.setResponseMessage(null);
        dispatch.setRespondedAt(null);

        dispatch = dispatchRepository.save(dispatch);

        if ("open".equals(req.getStatus())) {
            req.setStatus("matching");
            helpRequestRepository.save(req);
        }

        return dispatch;
    }

    @Transactional
    public HelpDispatch respondToDispatch(Integer dispatchId, Integer actorId, Map<String, Object> attrs) {
        var dispatch = dispatchRepository.findById(dispatchId).orElseThrow();
        var req = dispatch.getHelpRequest();
        boolean isRequester = dispatch.getRequester().getId().equals(actorId);
        boolean isHelper = dispatch.getHelper().getId().equals(actorId);
        if (!isRequester && !isHelper) throw ApiException.forbidden();

        String status = (String) attrs.get("status");
        if (status == null || status.isBlank()) {
            throw ApiException.badRequest("status", "status is required.");
        }

        var allowed = isHelper
                ? java.util.Set.of("accepted", "declined")
                : java.util.Set.of("cancelled");
        if (!allowed.contains(status)) {
            throw ApiException.badRequest("status", "This user cannot set dispatch status to " + status + ".");
        }
        if (!"pending".equals(dispatch.getStatus()) && !status.equals(dispatch.getStatus())) {
            throw ApiException.badRequest("status", "This dispatch has already been resolved.");
        }

        dispatch.setStatus(status);
        if (attrs.containsKey("responseMessage")) {
            dispatch.setResponseMessage(v.string(attrs, "responseMessage", 2000, false));
        }
        if (attrs.containsKey("meetingHint")) {
            dispatch.setMeetingHint(v.string(attrs, "meetingHint", 255, false));
        }
        if (attrs.containsKey("meetingSafetyState")) {
            dispatch.setMeetingSafetyState(v.oneOf(attrs, "meetingSafetyState",
                    java.util.Set.of("not_arranged", "public_place_suggested", "public_place_confirmed"),
                    dispatch.getMeetingSafetyState()));
        }
        dispatch.setRespondedAt(LocalDateTime.now());

        if ("accepted".equals(status)) {
            var existing = matchRepository.findByHelpRequestIdAndHelperId(req.getId(), dispatch.getHelper().getId());
            HelpMatch match = existing.orElseGet(() -> {
                var m = new HelpMatch();
                m.setHelpRequest(req);
                m.setHelper(dispatch.getHelper());
                m.setMessage(dispatch.getResponseMessage());
                return m;
            });
            match.setStatus("accepted");
            match.setMeetingHint(dispatch.getMeetingHint());
            match.setMeetingSafetyState(dispatch.getMeetingSafetyState());
            if (match.getAcceptedAt() == null) match.setAcceptedAt(LocalDateTime.now());
            match = matchRepository.save(match);
            dispatch.setMatch(match);
            req.setStatus("matched");
            req.setMeetingSafetyState(match.getMeetingSafetyState());
            helpRequestRepository.save(req);
            events.record(match, actorId, "helper", "match.accepted", "match", match.getId(),
                    "派单已接受，协作工作区已开启");
        }

        return dispatchRepository.save(dispatch);
    }

    @Transactional
    public HelpMatchMessage sendMessage(Integer matchId, Integer userId, String content,
                                        String agentContext, String kind, String clientRequestId) {
        var match = matchRepository.findById(matchId).orElseThrow();
        var req = match.getHelpRequest();
        boolean isRequester = req.getRequester().getId().equals(userId);
        boolean isHelper = match.getHelper().getId().equals(userId);

        if (!isRequester && !isHelper) {
            throw ApiException.forbidden();
        }
        if (!"accepted".equals(match.getStatus())) {
            throw ApiException.badRequest("status",
                    "Messages can only be sent in accepted matches.");
        }
        if (content == null || content.isBlank()) {
            throw ApiException.badRequest("content", "content is required.");
        }
        if (clientRequestId != null && !clientRequestId.isBlank()) {
            var existing = messageRepository.findByMatchIdAndClientRequestId(
                    matchId, clientRequestId.trim());
            if (existing.isPresent()) return existing.get();
        }
        String normalizedKind = kind == null || kind.isBlank() ? "chat" : kind.trim();
        if (!MESSAGE_KINDS.contains(normalizedKind)) {
            throw ApiException.badRequest("kind",
                    "kind must be one of: " + String.join(", ", MESSAGE_KINDS) + ".");
        }

        var msg = new HelpMatchMessage();
        msg.setMatch(match);
        var u = new User(); u.setId(userId); msg.setUser(u);
        msg.setContent(content);
        msg.setAgentContext(agentContext);
        msg.setKind(normalizedKind);
        msg.setClientRequestId(clientRequestId == null || clientRequestId.isBlank()
                ? null : clientRequestId.trim());
        return messageRepository.save(msg);
    }
}
