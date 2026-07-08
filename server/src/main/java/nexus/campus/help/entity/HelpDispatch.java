package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_help_dispatches",
       uniqueConstraints = @UniqueConstraint(columnNames = {"help_request_id", "helper_user_id"}))
@Getter @Setter @NoArgsConstructor
public class HelpDispatch {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "help_request_id", nullable = false)
    private HelpRequest helpRequest;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_user_id", nullable = false)
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "helper_user_id", nullable = false)
    private User helper;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id")
    private HelpMatch match;

    @Column(nullable = false, length = 40)
    private String status = "pending";

    @Column(columnDefinition = "text")
    private String message;

    @Column(columnDefinition = "text")
    private String rationale;

    @Column(name = "response_message", columnDefinition = "text")
    private String responseMessage;

    @Column(name = "meeting_hint", length = 255)
    private String meetingHint;

    @Column(name = "meeting_safety_state", length = 40)
    private String meetingSafetyState = "not_arranged";

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @Column(name = "responded_at")
    private LocalDateTime respondedAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
