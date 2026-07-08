package nexus.campus.auth.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "api_keys")
@Getter @Setter @NoArgsConstructor
public class ApiKey {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "token_key", nullable = false, unique = true, length = 64)
    private String tokenKey;

    @Column(name = "user_id", nullable = false)
    private Integer userId;

    @Column(name = "created_at")
    private Instant createdAt;
}
