package nexus.campus.help.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.help.repository.HelpDispatchRepository;
import nexus.campus.help.repository.HelpMatchRepository;
import nexus.campus.help.repository.HelpRequestRepository;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@RequiredArgsConstructor
public class WorkItemFeedService {

    private final HelpDispatchRepository dispatchRepository;
    private final HelpMatchRepository matchRepository;
    private final HelpRequestRepository helpRequestRepository;

    public record WorkItem(String kind, String role, Integer id, String status, String title,
                           Integer relatedUserId, Map<String, Object> actionRef) {}

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
