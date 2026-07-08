package nexus.campus.forum.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "posts")
@Getter @Setter @NoArgsConstructor
public class Post {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "discussion_id", nullable = false)
    private Discussion discussion;

    @Column(nullable = false)
    private Integer number;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, columnDefinition = "text")
    private String content;

    @Column(length = 100)
    private String type = "comment";

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "edited_at")
    private LocalDateTime editedAt;

    @Column(name = "hidden_at")
    private LocalDateTime hiddenAt;

    @Column(name = "is_private")
    private boolean isPrivate;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @PrePersist
    protected void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }
}
