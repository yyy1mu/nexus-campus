package nexus.campus.security.authorization;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.repository.AgentProfileRepository;
import nexus.campus.common.exception.ApiException;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AgentAuthorizationService {

    private final AgentProfileRepository agentProfileRepository;

    public void assertMatchingAllowed(Integer userId, String actionName) {
        assertPermission(userId, "allowAgentMatching", "allow_agent_matching", actionName);
    }

    public void assertPermission(Integer userId, String attributeName, String column, String actionName) {
        var profile = agentProfileRepository.findByUser_Id(userId);
        String msg = "Enable " + attributeName +
                " in /api/nexus/me/agent-profile before allowing an agent to " + actionName + ".";
        if (profile.isEmpty()) throw ApiException.badRequest(attributeName, msg);

        boolean permitted = switch (column) {
            case "allow_agent_matching" -> profile.get().isAllowAgentMatching();
            case "allow_agent_posting" -> profile.get().isAllowAgentPosting();
            case "allow_agent_replying" -> profile.get().isAllowAgentReplying();
            case "allow_location_matching" -> profile.get().isAllowLocationMatching();
            default -> false;
        };
        if (!permitted) throw ApiException.badRequest(attributeName, msg);
    }
}
