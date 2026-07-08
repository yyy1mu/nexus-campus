package nexus.campus.agent.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_agent_action_logs")
@Getter @Setter @NoArgsConstructor
public class AgentActionLog {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "action_type", nullable = false, length = 120)
    private String actionType;

    @Column(name = "target_type", nullable = false, length = 120)
    private String targetType;

    @Column(name = "target_id")
    private Integer targetId;

    @Column(length = 40)
    private String status = "succeeded";

    @Column(name = "user_confirmed")
    private boolean userConfirmed;

    @Column(name = "input_summary", columnDefinition = "text")
    private String inputSummary;

    @Column(name = "output_summary", columnDefinition = "text")
    private String outputSummary;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }
}
