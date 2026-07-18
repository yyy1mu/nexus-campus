package nexus.campus.agent.memory.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class MatchMemoryShareResponse {
    private Integer id;
    private Integer matchId;
    private Integer memoryId;
    private Integer ownerUserId;
    private Integer sharedByUserId;
    private String kind;
    private String title;
    private String content;
    private List<String> tags;
    private String sensitivity;
    private LocalDateTime createdAt;
    private LocalDateTime revokedAt;
}
