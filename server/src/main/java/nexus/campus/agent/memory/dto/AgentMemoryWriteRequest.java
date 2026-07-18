package nexus.campus.agent.memory.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class AgentMemoryWriteRequest {
    private String kind;
    private String title;
    private String content;
    private List<String> tags;
    private String status;
    private Integer importance;
    private Boolean pinned;
    private String sourceType;
    private String sourceRef;
    private String sensitivity;
    private String sharePolicy;
    private LocalDateTime validFrom;
    private LocalDateTime expiresAt;
    private Boolean clearExpiresAt;
    private Boolean userConfirmed;
}
