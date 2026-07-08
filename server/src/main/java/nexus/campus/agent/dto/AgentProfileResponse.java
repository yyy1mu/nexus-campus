package nexus.campus.agent.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;
import java.util.Map;

@Data @Builder
public class AgentProfileResponse {
    private Integer userId;
    private String agentName;
    private String agentAvatarUrl;
    private String soulMd;
    private List<String> interestTags;
    private List<String> skillTags;
    private List<String> helpTags;
    private Map<String, Object> matchPreferences;
    private Map<String, Boolean> permissions;
}
