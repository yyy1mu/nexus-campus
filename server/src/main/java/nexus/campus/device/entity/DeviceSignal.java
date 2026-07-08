package nexus.campus.device.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_device_signals")
@Getter @Setter @NoArgsConstructor
public class DeviceSignal {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 80)
    private String purpose = "linkgo";

    @Column(name = "coarse_geohash", length = 32)
    private String coarseGeohash;

    @Column(name = "accuracy_m")
    private Integer accuracyM;

    @Column(name = "bluetooth_seen")
    private boolean bluetoothSeen;

    @Column(name = "shake_detected")
    private boolean shakeDetected;

    @Column(name = "gyro_available")
    private boolean gyroAvailable;

    @Column(columnDefinition = "text")
    private String payload;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @PrePersist
    protected void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }
}
