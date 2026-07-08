package nexus.campus.common.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(unique = true, nullable = false, length = 100)
    private String username;

    @Column(unique = true, nullable = false, length = 200)
    private String email;

    @Column(nullable = false, length = 100)
    private String password;

    @Column(name = "joined_at")
    private Instant joinedAt;

    @Column(name = "is_email_confirmed")
    private boolean isEmailConfirmed = true;
}
