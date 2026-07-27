package nexus.campus.help.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_match_events",
       indexes = @Index(name = "idx_match_events_match_id_id", columnList = "match_id, id"))
@Getter @Setter @NoArgsConstructor
public class MatchEvent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "match_id", nullable = false)
    private HelpMatch match;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_user_id")
    private User actor;

    @Column(name = "actor_role", length = 16)
    private String actorRole;

    @Column(name = "event_type", nullable = false, length = 60)
    private String eventType;

    @Column(name = "ref_type", length = 30)
    private String refType;

    @Column(name = "ref_id")
    private Integer refId;

    @Column(nullable = false, length = 500)
    private String summary;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); }
}
