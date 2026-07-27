package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_match_tasks",
       uniqueConstraints = @UniqueConstraint(columnNames = {"match_id", "client_request_id"}))
@Getter @Setter @NoArgsConstructor
public class MatchTask {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id", nullable = false)
    private HelpMatch match;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private User createdBy;

    @Column(name = "owner_role", nullable = false, length = 16)
    private String ownerRole;

    @Column(nullable = false, length = 160)
    private String title;

    @Column(columnDefinition = "text")
    private String note;

    @Column(nullable = false, length = 16)
    private String status = "todo";

    @Column(name = "blocked_reason", length = 500)
    private String blockedReason;

    @Column(name = "order_index", nullable = false)
    private Integer orderIndex = 0;

    @Column(name = "client_request_id", length = 80)
    private String clientRequestId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "done_at")
    private LocalDateTime doneAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
