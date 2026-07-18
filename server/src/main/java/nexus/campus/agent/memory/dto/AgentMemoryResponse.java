package nexus.campus.agent.memory.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AgentMemoryResponse {
    private Integer id;
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
    private LocalDateTime lastAccessedAt;
    private Integer accessCount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private Double retrievalScore;
}
