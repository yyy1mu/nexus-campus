package nexus.campus.security.authorization;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
@RequiredArgsConstructor
public class AgentWriteGuard {

    private final AgentAuthorizationService authorization;

    public void requireUser(User user) {
        if (user == null || user.getId() == null) {
            throw ApiException.unauthenticated();
        }
    }

    public void requireConfirmed(Map<String, Object> attrs) {
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed"))) {
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");
        }
    }

    public void requireConfirmedUser(User user, Map<String, Object> attrs) {
        requireUser(user);
        requireConfirmed(attrs);
    }

    public void requireMatching(User user, Map<String, Object> attrs, String actionName) {
        requireConfirmedUser(user, attrs);
        authorization.assertMatchingAllowed(user.getId(), actionName);
    }

    public void requirePosting(User user, Map<String, Object> attrs, String actionName) {
        requireConfirmedUser(user, attrs);
        authorization.assertPermission(user.getId(), "allowAgentPosting", "allow_agent_posting", actionName);
    }

    public void requireReplying(User user, Map<String, Object> attrs, String actionName) {
        requireConfirmedUser(user, attrs);
        authorization.assertPermission(user.getId(), "allowAgentReplying", "allow_agent_replying", actionName);
    }
}
