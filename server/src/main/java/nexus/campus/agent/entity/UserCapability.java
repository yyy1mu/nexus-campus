package nexus.campus.agent.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_user_capabilities",
       uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "label"}))
@Getter @Setter @NoArgsConstructor
public class UserCapability {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 80)
    private String label;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(columnDefinition = "text")
    private String summary;

    @Column(length = 80)
    private String availability;

    @Column(name = "service_radius_m")
    private Integer serviceRadiusM;

    @Column(name = "is_active")
    private boolean isActive = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
