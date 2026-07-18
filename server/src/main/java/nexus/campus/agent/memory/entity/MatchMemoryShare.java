package nexus.campus.agent.memory.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;
import nexus.campus.help.entity.HelpMatch;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_match_memory_shares",
        uniqueConstraints = @UniqueConstraint(
                name = "nmms_match_memory_unique",
                columnNames = {"match_id", "memory_id"}),
        indexes = @Index(
                name = "nmms_match_revoked_idx",
                columnList = "match_id,revoked_at"))
@Getter
@Setter
@NoArgsConstructor
public class MatchMemoryShare {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id", nullable = false)
    private HelpMatch match;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "memory_id", nullable = false)
    private AgentMemory memory;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_user_id", nullable = false)
    private User owner;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shared_by_user_id", nullable = false)
    private User sharedBy;

    @Column(name = "snapshot_kind", nullable = false, length = 40)
    private String snapshotKind;

    @Column(name = "snapshot_title", nullable = false, length = 160)
    private String snapshotTitle;

    @Column(name = "snapshot_content", nullable = false, columnDefinition = "text")
    private String snapshotContent;

    @Column(name = "snapshot_tags", columnDefinition = "text")
    private String snapshotTags;

    @Column(name = "snapshot_sensitivity", nullable = false, length = 24)
    private String snapshotSensitivity;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "revoked_at")
    private LocalDateTime revokedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
