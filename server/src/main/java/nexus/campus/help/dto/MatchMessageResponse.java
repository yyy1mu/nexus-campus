package nexus.campus.help.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data @Builder
public class MatchMessageResponse {
    private Integer id, matchId, userId;
    private String content, kind;
    private LocalDateTime createdAt;
}
