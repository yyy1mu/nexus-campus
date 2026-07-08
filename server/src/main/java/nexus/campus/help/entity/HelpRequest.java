package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "nexus_help_requests")
@Getter @Setter @NoArgsConstructor
public class HelpRequest {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "discussion_id", unique = true)
    private Integer discussionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_user_id", nullable = false)
    private User requester;

    @Column(nullable = false, length = 40)
    private String status = "open";

    @Column(name = "category_label", length = 80)
    private String categoryLabel;

    @Column(name = "needed_labels", columnDefinition = "text")
    private String neededLabels;

    @Column(columnDefinition = "text")
    private String summary;

    @Column(length = 40)
    private String urgency = "normal";

    @Column(name = "location_hint", length = 255)
    private String locationHint;

    @Column(name = "meeting_safety_state", length = 40)
    private String meetingSafetyState = "not_arranged";

    @Column(name = "agent_context", columnDefinition = "text")
    private String agentContext;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "closed_at")
    private LocalDateTime closedAt;

    @OneToMany(mappedBy = "helpRequest", fetch = FetchType.LAZY)
    private List<HelpMatch> matches;

    @OneToMany(mappedBy = "helpRequest", fetch = FetchType.LAZY)
    private List<HelpDispatch> dispatches;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
