package nexus.campus.forum.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "discussions")
@Getter @Setter @NoArgsConstructor
public class Discussion {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 255)
    private String slug;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "comment_count")
    private Integer commentCount = 1;

    @Column(name = "participant_count")
    private Integer participantCount = 1;

    @Column(name = "is_sticky")
    private boolean isSticky;

    @Column(name = "is_locked")
    private boolean isLocked;

    @Column(name = "is_private")
    private boolean isPrivate;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "hidden_at")
    private LocalDateTime hiddenAt;

    @Column(name = "last_posted_at")
    private LocalDateTime lastPostedAt;

    @Column(name = "last_posted_user_id")
    private Integer lastPostedUserId;

    @Column(name = "first_post_id")
    private Integer firstPostId;

    @Column(name = "last_post_number")
    private Integer lastPostNumber;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "first_post_id", insertable = false, updatable = false)
    private Post firstPost;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(name = "discussion_tag",
            joinColumns = @JoinColumn(name = "discussion_id"),
            inverseJoinColumns = @JoinColumn(name = "tag_id"))
    private List<Tag> tags;

    @OneToMany(mappedBy = "discussion", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @OrderBy("number ASC")
    private List<Post> posts;

    @PrePersist
    protected void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }
}
