package nexus.campus.agent.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import nexus.campus.agent.entity.AgentProfile;
import nexus.campus.agent.repository.AgentProfileRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AgentProfileService {

    private final AgentProfileRepository profileRepository;
    private final ObjectMapper objectMapper;

    public AgentProfile getOrCreate(Integer userId) {
        return profileRepository.findByUser_Id(userId).orElseGet(() -> {
            var profile = new AgentProfile();
            profile.setUserId(userId);
            profile.setAllowAgentPosting(false);
            profile.setAllowAgentReplying(false);
            profile.setAllowAgentMatching(false);
            profile.setAllowLocationMatching(false);
            profile.setLocationVisibility("off");
            return profile;
        });
    }

    @Transactional
    public AgentProfile update(Integer userId, Map<String, Object> attributes) {
        var profile = getOrCreate(userId);

        if (attributes.containsKey("agentName"))
            profile.setAgentName(truncate(attributes.get("agentName"), 120));
        if (attributes.containsKey("agentAvatarUrl"))
            profile.setAgentAvatarUrl(truncate(attributes.get("agentAvatarUrl"), 512));
        if (attributes.containsKey("soulMd"))
            profile.setSoulMd(truncate(attributes.get("soulMd"), 12000));
        if (attributes.containsKey("interestTags"))
            profile.setInterestTags(encodeList(attributes.get("interestTags")));
        if (attributes.containsKey("skillTags"))
            profile.setSkillTags(encodeList(attributes.get("skillTags")));
        if (attributes.containsKey("helpTags"))
            profile.setHelpTags(encodeList(attributes.get("helpTags")));
        if (attributes.containsKey("matchPreferences"))
            profile.setMatchPreferences(encodeMap(attributes.get("matchPreferences")));

        if (attributes.containsKey("permissions")) {
            @SuppressWarnings("unchecked")
            var perms = (Map<String, Object>) attributes.get("permissions");
            if (perms.containsKey("allowAgentPosting"))
                profile.setAllowAgentPosting(Boolean.TRUE.equals(perms.get("allowAgentPosting")));
            if (perms.containsKey("allowAgentReplying"))
                profile.setAllowAgentReplying(Boolean.TRUE.equals(perms.get("allowAgentReplying")));
            if (perms.containsKey("allowAgentMatching"))
                profile.setAllowAgentMatching(Boolean.TRUE.equals(perms.get("allowAgentMatching")));
            if (perms.containsKey("allowLocationMatching"))
                profile.setAllowLocationMatching(Boolean.TRUE.equals(perms.get("allowLocationMatching")));
        }

        return profileRepository.save(profile);
    }

    private String truncate(Object value, int max) {
        if (value == null) return null;
        String s = value.toString().trim();
        if (s.isEmpty()) return null;
        return s.length() > max ? s.substring(0, max) : s;
    }

    private String encodeList(Object value) {
        if (value == null) return null;
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            return null;
        }
    }

    private String encodeMap(Object value) {
        if (value == null || (value instanceof Map<?,?> m && m.isEmpty())) return null;
        try {
            String json = objectMapper.writeValueAsString(value);
            return json.length() > 4000 ? null : json;
        } catch (JsonProcessingException e) {
            return null;
        }
    }
}
