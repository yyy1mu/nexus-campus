package nexus.campus.help.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.help.repository.HelpDispatchRepository;
import nexus.campus.help.repository.HelpMatchRepository;
import nexus.campus.help.repository.HelpRequestRepository;
import nexus.campus.help.repository.MatchDecisionRepository;
import nexus.campus.help.repository.MatchDeliverableRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@RequiredArgsConstructor
public class WorkItemFeedService {

    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchRepository matchRepository;
    private final HelpRequestRepository helpRequestRepository;
    private final MatchDecisionRepository decisionRepository;
    private final MatchDeliverableRepository deliverableRepository;

    public record WorkItem(String kind, String role, Integer id, String status, String title,
                           Integer relatedUserId, Map<String, Object> actionRef) {}

    @Transactional(readOnly = true)
    public List<WorkItem> forUser(Integer userId) {
        var items = new ArrayList<WorkItem>();

        // Helper dispatches (pending dispatches where user is the helper)
        dispatchRepository.findByHelperIdOrderByCreatedAtDesc(userId).stream()
                .filter(d -> "pending".equals(d.getStatus()))
                .forEach(d -> items.add(new WorkItem("dispatch", "helper", d.getId(), d.getStatus(),
                        "Dispatch #" + d.getId(),
                        d.getRequester().getId(),
                        Map.of("action", "dispatch.update", "endpoint", "/api/nexus/dispatches/" + d.getId()))));

        // Matches where user is helper (offered matches)
        matchRepository.findByHelperIdOrderByCreatedAtDesc(userId).stream()
                .filter(m -> "offered".equals(m.getStatus()) || "accepted".equals(m.getStatus()))
                .forEach(m -> items.add(new WorkItem("match", "helper", m.getId(), m.getStatus(),
                        "Match #" + m.getId(),
                        m.getHelpRequest().getRequester().getId(),
                        Map.of("action", "match.update", "endpoint", "/api/nexus/matches/" + m.getId()))));

        // Open decisions waiting for this user's confirmation (handoff points)
        var openDecisions = new ArrayList<nexus.campus.help.entity.MatchDecision>();
        openDecisions.addAll(decisionRepository
                .findByStatusAndAssignedRoleAndMatch_HelpRequest_Requester_Id("open", "requester", userId));
        openDecisions.addAll(decisionRepository
                .findByStatusAndAssignedRoleAndMatch_Helper_Id("open", "helper", userId));
        openDecisions.stream()
                .filter(d -> "accepted".equals(d.getMatch().getStatus()))
                .forEach(d -> items.add(new WorkItem("match_decision", d.getAssignedRole(), d.getId(),
                        d.getStatus(), "待决策：" + d.getTitle(),
                        d.getRaisedBy().getId(),
                        Map.of("action", "match_decision.resolve",
                                "endpoint", "/api/nexus/matches/" + d.getMatch().getId()
                                        + "/decisions/" + d.getId(),
                                "workspace", "/api/nexus/matches/" + d.getMatch().getId() + "/workspace"))));

        // Deliverables waiting for this user's review
        var pendingReviews = new ArrayList<nexus.campus.help.entity.MatchDeliverable>();
        pendingReviews.addAll(deliverableRepository
                .findByStatusAndSubmitterRoleAndMatch_HelpRequest_Requester_Id("submitted", "helper", userId));
        pendingReviews.addAll(deliverableRepository
                .findByStatusAndSubmitterRoleAndMatch_Helper_Id("submitted", "requester", userId));
        pendingReviews.stream()
                .filter(d -> "accepted".equals(d.getMatch().getStatus()))
                .forEach(d -> items.add(new WorkItem("match_deliverable",
                        "helper".equals(d.getSubmitterRole()) ? "requester" : "helper",
                        d.getId(), d.getStatus(), "待验收：" + d.getTitle(),
                        d.getSubmittedBy().getId(),
                        Map.of("action", "match_deliverable.review",
                                "endpoint", "/api/nexus/matches/" + d.getMatch().getId()
                                        + "/deliverables/" + d.getId(),
                                "workspace", "/api/nexus/matches/" + d.getMatch().getId() + "/workspace"))));

        // Help requests owned by user
        helpRequestRepository.findByRequesterIdOrderByCreatedAtDesc(userId).stream()
                .filter(r -> !java.util.Set.of("closed", "cancelled").contains(r.getStatus()))
                .forEach(r -> items.add(new WorkItem("help_request", "requester", r.getId(), r.getStatus(),
                        r.getSummary() != null ? r.getSummary() : "Request #" + r.getId(),
                        userId,
                        Map.of("action", "help_request.update", "endpoint", "/api/nexus/help-requests/" + r.getId()))));

        return items;
    }
}
