package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_match_decisions",
       uniqueConstraints = @UniqueConstraint(columnNames = {"match_id", "client_request_id"}))
@Getter @Setter @NoArgsConstructor
public class MatchDecision {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id", nullable = false)
    private HelpMatch match;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "raised_by_user_id", nullable = false)
    private User raisedBy;

    @Column(name = "raised_by_role", nullable = false, length = 16)
    private String raisedByRole;

    @Column(name = "assigned_role", nullable = false, length = 16)
    private String assignedRole;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String context;

    @Column(name = "options_json", nullable = false, columnDefinition = "text")
    private String optionsJson;

    @Column(nullable = false, length = 16)
    private String status = "open";

    @Column(name = "decided_option_key", length = 80)
    private String decidedOptionKey;

    @Column(name = "decision_note", length = 1000)
    private String decisionNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "decided_by_user_id")
    private User decidedBy;

    @Column(name = "decided_at")
    private LocalDateTime decidedAt;

    @Column(name = "client_request_id", length = 80)
    private String clientRequestId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
