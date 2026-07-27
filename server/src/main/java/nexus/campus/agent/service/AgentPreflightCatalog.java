package nexus.campus.agent.service;

import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class AgentPreflightCatalog {

    public static final String PUBLIC_FOOTER = "Posted by Nexus Agent after explicit user confirmation.";
    public static final String HELP_FOOTER = "Drafted by Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.";
    public static final String MATCH_OFFER_FOOTER = "Offered through Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.";
    public static final String DISPATCH_ACCEPT_FOOTER = "Accepted through Nexus Agent after explicit user confirmation. Offline coordination should prefer public, safe, easy-to-leave places.";

    private static final Map<String, String> PERMISSION_COLUMNS = Map.of(
        "allowAgentPosting", "allow_agent_posting",
        "allowAgentReplying", "allow_agent_replying",
        "allowAgentMatching", "allow_agent_matching",
        "allowLocationMatching", "allow_location_matching"
    );

    private final Map<String, Map<String, Object>> catalog;

    public AgentPreflightCatalog() {
        catalog = buildCatalog();
    }

    public Set<String> actionNames() { return catalog.keySet(); }
    public boolean hasAction(String action) { return catalog.containsKey(action); }
    public Map<String, Object> definition(String action) { return catalog.get(action); }
    public static String permissionColumn(String perm) { return PERMISSION_COLUMNS.get(perm); }

    private Map<String, Map<String, Object>> buildCatalog() {
        var c = new LinkedHashMap<String, Map<String, Object>>();

        c.put("need_draft", Map.of(
            "endpoint", "POST /api/nexus/need-drafts",
            "requiresConfirmation", false,
            "permissions", List.of(),
            "purpose", "Classify a raw natural-language user need, return a draft and read-only discoveryPlan, and avoid publishing or writing database state.",
            "proposedFields", List.of("rawUserNeed", "intent", "locationHint"),
            "sideEffects", Map.of(
                "writesDatabase", false,
                "createsPublicContent", false,
                "createsActionLog", false,
                "visibility", "private_to_calling_agent_response"
            )
        ));

        c.put("forum_discussion.create", Map.of(
            "endpoint", "POST /api/nexus/forum/discussions",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentPosting"),
            "purpose", "Create a general forum discussion through the Nexus gateway after the user confirms the exact public title, body, and tags.",
            "proposedFields", List.of("title", "content", "tagIds", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", true,
                "createsPublicDiscussion", true,
                "visibility", "public_forum",
                "serverAppendedFooter", PUBLIC_FOOTER
            )
        ));

        c.put("forum_post.reply", Map.of(
            "endpoint", "POST /api/nexus/forum/discussions/{id}/posts",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentReplying"),
            "purpose", "Reply to an existing forum discussion through the Nexus gateway after the user confirms the exact public reply.",
            "proposedFields", List.of("content", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", true,
                "createsPublicReply", true,
                "visibility", "public_forum",
                "serverAppendedFooter", PUBLIC_FOOTER
            )
        ));

        c.put("agent_profile.update", Map.of(
            "endpoint", "PATCH /api/nexus/me/agent-profile",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Update the current user's private Agent Profile, soul.md metadata, preferences, or authorization switches after explicit confirmation.",
            "proposedFields", List.of("agentName", "soulMd", "interestTags", "skillTags", "helpTags",
                    "matchPreferences", "permissions", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "private_to_user"
            )
        ));

        c.put("capabilities.update", Map.of(
            "endpoint", "PATCH /api/nexus/me/capabilities",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Update the current user's public capability labels after explicit confirmation.",
            "proposedFields", List.of("capabilities", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", true,
                "visibility", "public_capability_catalog"
            )
        ));

        c.put("memory.create", Map.of(
            "endpoint", "POST /api/nexus/me/memories",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Store a durable private memory after the user confirms the exact content, sensitivity, retention, and sharing policy.",
            "proposedFields", List.of("kind", "title", "content", "tags", "importance",
                    "pinned", "sourceType", "sourceRef", "sensitivity", "sharePolicy",
                    "validFrom", "expiresAt", "userConfirmed"),
            "sideEffects", Map.of(
                    "createsPublicContent", false,
                    "visibility", "private_to_user",
                    "credentialsAllowed", false)
        ));

        c.put("memory.update", Map.of(
            "endpoint", "PATCH /api/nexus/me/memories/{id}",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Correct, archive, reprioritize, or change the retention policy of a private memory after explicit confirmation.",
            "proposedFields", List.of("kind", "title", "content", "tags", "status",
                    "importance", "pinned", "sensitivity", "sharePolicy", "expiresAt",
                    "clearExpiresAt", "userConfirmed"),
            "sideEffects", Map.of(
                    "createsPublicContent", false,
                    "visibility", "private_to_user")
        ));

        c.put("memory.delete", Map.of(
            "endpoint", "DELETE /api/nexus/me/memories/{id}",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Permanently delete a private memory and its match-share snapshots after explicit confirmation.",
            "proposedFields", List.of("userConfirmed"),
            "sideEffects", Map.of(
                    "destructive", true,
                    "visibility", "private_to_user")
        ));

        c.put("memory_share.create", Map.of(
            "endpoint", "POST /api/nexus/matches/{id}/memory-shares",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Share selected ask_each_time memories as immutable snapshots with the other participant of an accepted match.",
            "proposedFields", List.of("memoryIds", "userConfirmed"),
            "sideEffects", Map.of(
                    "createsPublicContent", false,
                    "visibility", "accepted_match_participants_only",
                    "snapshot", true)
        ));

        c.put("memory_share.revoke", Map.of(
            "endpoint", "PATCH /api/nexus/matches/{matchId}/memory-shares/{shareId}",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Revoke one of the current user's memory snapshots from a match after explicit confirmation.",
            "proposedFields", List.of("revoked", "userConfirmed"),
            "sideEffects", Map.of(
                    "createsPublicContent", false,
                    "visibility", "accepted_match_participants_only")
        ));

        c.put("help_request.create", Map.of(
            "endpoint", "POST /api/nexus/help-requests",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Create a public help request after the user explicitly confirms the exact title, summary, labels, visibility, and safety notes.",
            "proposedFields", List.of("title", "summary", "content", "neededLabels", "categoryLabel",
                    "urgency", "locationHint", "meetingSafetyState", "agentContext", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", true,
                "createsPublicDiscussionAndHelpRequest", true,
                "visibility", "public_help_board",
                "serverAppendedFooter", HELP_FOOTER
            )
        ));

        c.put("dispatch.create", Map.of(
            "endpoint", "POST /api/nexus/help-requests/{id}/dispatches",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Dispatch a help request to a specific helper after the requester confirms.",
            "proposedFields", List.of("helperUserId", "message", "rationale", "meetingHint",
                    "meetingSafetyState", "expiresAt", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "sendsNotification", true,
                "visibility", "requester_and_helper_only"
            )
        ));

        c.put("match.create", Map.of(
            "endpoint", "POST /api/nexus/help-requests/{id}/matches",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Offer help on a help request after the helper explicitly confirms.",
            "proposedFields", List.of("message", "meetingHint", "meetingSafetyState", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", true,
                "postsInDiscussion", true,
                "visibility", "requester_and_helper_with_public_post",
                "serverAppendedFooter", MATCH_OFFER_FOOTER
            )
        ));

        c.put("match_message.create", Map.of(
            "endpoint", "POST /api/nexus/matches/{id}/messages",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Send a private coordination message within an accepted match after explicit confirmation. Use kind (chat|update|question|handoff) and clientRequestId for safe retries.",
            "proposedFields", List.of("content", "kind", "clientRequestId", "agentContext", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "idempotency", "clientRequestId replays return the original message"
            )
        ));

        c.put("match_task.create", Map.of(
            "endpoint", "POST /api/nexus/matches/{id}/tasks",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Add a shared task to an accepted match's collaboration plan so both sides can track progress.",
            "proposedFields", List.of("title", "note", "ownerRole", "clientRequestId", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "idempotency", "clientRequestId replays return the original task",
                "blockedWhilePaused", true
            )
        ));

        c.put("match_task.update", Map.of(
            "endpoint", "PATCH /api/nexus/matches/{id}/tasks/{taskId}",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Advance, block (with blockedReason), retitle, or hand over a shared collaboration task. Status changes are allowed only for the side that owns the task.",
            "proposedFields", List.of("status", "title", "note", "ownerRole", "blockedReason", "orderIndex", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "blockedWhilePaused", true
            )
        ));

        c.put("match_decision.create", Map.of(
            "endpoint", "POST /api/nexus/matches/{id}/decisions",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Open a human decision gate with 2-5 concrete options. assignedRole must be the counterpart (cross-party checkpoint); work that depends on the choice must wait until the assigned human decides.",
            "proposedFields", List.of("title", "context", "options", "assignedRole", "clientRequestId", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "idempotency", "clientRequestId replays return the original decision",
                "blockedWhilePaused", true
            )
        ));

        c.put("match_decision.resolve", Map.of(
            "endpoint", "PATCH /api/nexus/matches/{id}/decisions/{decisionId}",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Record the assigned human participant's choice (action=decide with optionKey) or, as the raiser, withdraw an open decision (action=cancel). Human gate: requires userConfirmed only, not allowAgentMatching.",
            "proposedFields", List.of("action", "optionKey", "note", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "idempotency", "re-deciding with the same optionKey returns the decided record"
            )
        ));

        c.put("match_deliverable.create", Map.of(
            "endpoint", "POST /api/nexus/matches/{id}/deliverables",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Submit the agreed deliverable (title, access hint, checksum, license note) for the counterpart's review.",
            "proposedFields", List.of("title", "description", "accessHint", "checksum", "licenseNote", "clientRequestId", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only",
                "idempotency", "clientRequestId replays return the original deliverable",
                "blockedWhilePaused", true
            )
        ));

        c.put("match_deliverable.review", Map.of(
            "endpoint", "PATCH /api/nexus/matches/{id}/deliverables/{deliverableId}",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Accept or reject (with reviewNote) a counterpart deliverable, or withdraw one's own pending deliverable. A pending deliverable blocks match completion. Human gate: requires userConfirmed only, not allowAgentMatching.",
            "proposedFields", List.of("action", "reviewNote", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only"
            )
        ));

        c.put("match_workspace.update", Map.of(
            "endpoint", "PATCH /api/nexus/matches/{id}/workspace",
            "requiresConfirmation", true,
            "permissions", List.of("allowAgentMatching"),
            "purpose", "Pause or resume collaboration, or move the baton (requester|helper|none). While the baton is set, only the holder can create tasks, decisions, and deliverables. Paused workspaces reject new work. Human control: requires userConfirmed only, not allowAgentMatching.",
            "proposedFields", List.of("collaborationState", "baton", "note", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "match_participants_only"
            )
        ));

        c.put("device_signal.create", Map.of(
            "endpoint", "POST /api/nexus/device-signals",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Send device signals (geohash, sensors) after explicit user confirmation.",
            "proposedFields", List.of("purpose", "coarseGeohash", "accuracyM", "bluetoothSeen",
                    "shakeDetected", "gyroAvailable", "payload", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "private_to_user"
            )
        ));

        c.put("llm_settings.update", Map.of(
            "endpoint", "PATCH /api/nexus/llm-settings",
            "requiresConfirmation", true,
            "permissions", List.of(),
            "purpose", "Update the current user's optional forum-side LLM provider metadata after confirmation.",
            "proposedFields", List.of("provider", "baseUrl", "apiKey", "chatModel", "responsesModel",
                    "supportsChatCompletions", "supportsResponses", "userConfirmed"),
            "sideEffects", Map.of(
                "createsPublicContent", false,
                "visibility", "private_to_user"
            )
        ));

        return c;
    }
}
