package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "nexus_help_matches",
       uniqueConstraints = @UniqueConstraint(columnNames = {"help_request_id", "helper_user_id"}))
@Getter @Setter @NoArgsConstructor
public class HelpMatch {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "help_request_id", nullable = false)
    private HelpRequest helpRequest;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "helper_user_id", nullable = false)
    private User helper;

    @Column(nullable = false, length = 40)
    private String status = "offered";

    @Column(columnDefinition = "text")
    private String message;

    @Column(name = "meeting_hint", length = 255)
    private String meetingHint;

    @Column(name = "meeting_safety_state", length = 40)
    private String meetingSafetyState = "not_arranged";

    @Column(name = "collab_state", nullable = false, length = 16)
    private String collabState = "active";

    @Column(name = "baton_role", length = 16)
    private String batonRole;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "accepted_at")
    private LocalDateTime acceptedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @OneToMany(mappedBy = "match", fetch = FetchType.LAZY)
    private List<HelpMatchMessage> messages;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
