package nexus.campus.agent.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_user_llm_settings")
@Getter @Setter @NoArgsConstructor
public class UserLlmSettings {
    @Id
    @Column(name = "user_id")
    private Integer userId;

    @Column(length = 60)
    private String provider = "builtin";

    @Column(name = "base_url", length = 512)
    private String baseUrl;

    @Column(name = "chat_model", length = 120)
    private String chatModel;

    @Column(name = "responses_model", length = 120)
    private String responsesModel;

    @Column(name = "api_key", columnDefinition = "text")
    private String apiKey;

    @Column(name = "supports_chat_completions")
    private boolean supportsChatCompletions = true;

    @Column(name = "supports_responses")
    private boolean supportsResponses = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
