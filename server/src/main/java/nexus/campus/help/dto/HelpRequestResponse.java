package nexus.campus.help.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data @Builder
public class HelpRequestResponse {
    private Integer id;
    private Integer discussionId;
    private String discussionUrl;
    private Integer requesterUserId;
    private String status;
    private String categoryLabel;
    private List<String> neededLabels;
    private String summary;
    private String urgency;
    private String locationHint;
    private String meetingSafetyState;
    private Map<String, Object> agentContext;
    private List<Map<String, Object>> nextActions;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime closedAt;
}
