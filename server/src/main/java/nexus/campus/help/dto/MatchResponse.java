package nexus.campus.help.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data @Builder
public class MatchResponse {
    private Integer id, helpRequestId, requesterUserId, helperUserId;
    private String helpRequestSummary, status, message, meetingHint, meetingSafetyState;
    private String collaborationState, batonRole;
    private LocalDateTime createdAt, acceptedAt, completedAt, updatedAt;
}
