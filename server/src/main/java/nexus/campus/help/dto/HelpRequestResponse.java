package nexus.campus.help.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data @Builder
public class HelpRequestResponse {
    private Integer id;
    private Integer requesterUserId;
    private String status;
    private String categoryLabel;
    private String summary;
    private String locationHint;
    private String meetingSafetyState;
    private String urgency;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime closedAt;
}
