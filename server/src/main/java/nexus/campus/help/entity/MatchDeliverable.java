package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_match_deliverables",
       uniqueConstraints = @UniqueConstraint(columnNames = {"match_id", "client_request_id"}))
@Getter @Setter @NoArgsConstructor
public class MatchDeliverable {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id", nullable = false)
    private HelpMatch match;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "submitted_by_user_id", nullable = false)
    private User submittedBy;

    @Column(name = "submitter_role", nullable = false, length = 16)
    private String submitterRole;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "access_hint", length = 500)
    private String accessHint;

    @Column(length = 128)
    private String checksum;

    @Column(name = "license_note", length = 500)
    private String licenseNote;

    @Column(nullable = false, length = 16)
    private String status = "submitted";

    @Column(name = "review_note", length = 1000)
    private String reviewNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by_user_id")
    private User reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

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
