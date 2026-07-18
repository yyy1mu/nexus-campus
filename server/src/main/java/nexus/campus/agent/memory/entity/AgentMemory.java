package nexus.campus.agent.memory.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_agent_memories", indexes = {
        @Index(name = "nam_user_status_updated_idx", columnList = "user_id,status,updated_at"),
        @Index(name = "nam_user_kind_idx", columnList = "user_id,kind")
})
@Getter
@Setter
@NoArgsConstructor
public class AgentMemory {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 40)
    private String kind;

    @Column(nullable = false, length = 160)
    private String title;

    @Column(nullable = false, columnDefinition = "text")
    private String content;

    @Column(columnDefinition = "text")
    private String tags;

    @Column(nullable = false, length = 24)
    private String status = "active";

    @Column(nullable = false)
    private int importance = 3;

    @Column(nullable = false)
    private boolean pinned;

    @Column(name = "source_type", nullable = false, length = 40)
    private String sourceType = "user";

    @Column(name = "source_ref", length = 255)
    private String sourceRef;

    @Column(nullable = false, length = 24)
    private String sensitivity = "normal";

    @Column(name = "share_policy", nullable = false, length = 32)
    private String sharePolicy = "private";

    @Column(name = "valid_from")
    private LocalDateTime validFrom;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @Column(name = "last_accessed_at")
    private LocalDateTime lastAccessedAt;

    @Column(name = "access_count", nullable = false)
    private int accessCount;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
