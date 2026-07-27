package nexus.campus.agent.service;

import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class AgentNextActionEnricher {

    public Map<String, Object> enrich(String action, String purpose) {
        var result = new LinkedHashMap<String, Object>();
        result.put("action", action);
        result.put("purpose", purpose);
        result.put("requiresUserConfirmation", true);
        if (action.contains("help_request") || action.contains("dispatch") || action.contains("match"))
            result.put("requiredPermission", "allowAgentMatching");
        if (action.contains("forum"))
            result.put("requiredPermission", action.contains("post") ? "allowAgentReplying" : "allowAgentPosting");
        return result;
    }

    public List<Map<String, Object>> buildRequestNextActions(Integer helpRequestId) {
        return List.of(
                wrap("find_candidates", "GET", "/api/nexus/help-requests/" + helpRequestId + "/candidates",
                        "Find capable helpers before dispatching.", false),
                wrap("preflight_offer", "POST", "/api/nexus/agent-preflight",
                        "Dry-run match.create before offering help.", false),
                wrap("offer_match", "POST", "/api/nexus/help-requests/" + helpRequestId + "/matches",
                        "Offer help after helper confirms.", true)
        );
    }

    public List<Map<String, Object>> buildMatchNextActions(Integer matchId, String role, String status) {
        var actions = new ArrayList<Map<String, Object>>();
        if ("offered".equals(status) && "requester".equals(role)) {
            actions.add(wrap("accept_match", "PATCH", "/api/nexus/matches/" + matchId,
                    "Accept this offer after confirmation.", true));
            actions.add(wrap("decline_match", "PATCH", "/api/nexus/matches/" + matchId,
                    "Decline this offer.", true));
        }
        if ("accepted".equals(status)) {
            actions.add(wrap("get_workspace", "GET", "/api/nexus/matches/" + matchId + "/workspace",
                    "Load the shared collaboration workspace (tasks, decisions, deliverables, events). Use this to resume after interruption.", false));
            actions.add(wrap("sync_events", "GET", "/api/nexus/matches/" + matchId + "/events?afterId=<lastEventId>",
                    "Incrementally sync workspace events since the last seen id.", false));
            actions.add(wrap("list_messages", "GET", "/api/nexus/matches/" + matchId + "/messages",
                    "Read private messages. Supports afterId for incremental sync.", false));
            actions.add(wrap("send_message", "POST", "/api/nexus/matches/" + matchId + "/messages",
                    "Send private coordination message. Include clientRequestId to make retries safe.", true));
            actions.add(wrap("create_task", "POST", "/api/nexus/matches/" + matchId + "/tasks",
                    "Add a shared task to the collaboration plan.", true));
            actions.add(wrap("open_decision", "POST", "/api/nexus/matches/" + matchId + "/decisions",
                    "Raise a cross-party decision gate (assignedRole = counterpart) that their human must resolve before dependent work continues.", true));
            actions.add(wrap("submit_deliverable", "POST", "/api/nexus/matches/" + matchId + "/deliverables",
                    "Submit the agreed deliverable (access hint, checksum, license note) for counterpart review.", true));
            actions.add(wrap("pass_baton", "PATCH", "/api/nexus/matches/" + matchId + "/workspace",
                    "Move the baton or pause/resume. While the baton is set, only the holder can push new work.", true));
            actions.add(wrap("complete_match", "PATCH", "/api/nexus/matches/" + matchId,
                    "Requester-only: confirm completion after every decision gate is resolved and no deliverable is pending review.", true));
        }
        return actions;
    }

    public List<Map<String, Object>> buildDispatchNextActions(Integer dispatchId, String role, String status) {
        var actions = new ArrayList<Map<String, Object>>();
        if ("pending".equals(status) && "helper".equals(role)) {
            actions.add(wrap("accept_dispatch", "PATCH", "/api/nexus/dispatches/" + dispatchId,
                    "Accept dispatch invitation.", true));
            actions.add(wrap("decline_dispatch", "PATCH", "/api/nexus/dispatches/" + dispatchId,
                    "Decline dispatch.", true));
        }
        return actions;
    }

    private Map<String, Object> wrap(String name, String method, String endpoint, String purpose, boolean requiresConfirmation) {
        return Map.of("name", name, "method", method, "endpoint", endpoint,
                "purpose", purpose, "requiresUserConfirmation", requiresConfirmation);
    }
}
