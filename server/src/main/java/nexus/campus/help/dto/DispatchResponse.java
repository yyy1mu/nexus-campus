package nexus.campus.help.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data @Builder
public class DispatchResponse {
    private Integer id, helpRequestId, requesterUserId, helperUserId, matchId;
    private String status, message, rationale, responseMessage, meetingHint, meetingSafetyState;
    private LocalDateTime expiresAt, respondedAt, createdAt, updatedAt;
    private String viewerRole;
}
