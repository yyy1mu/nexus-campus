package nexus.campus.forum.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "tags")
@Getter @Setter @NoArgsConstructor
public class Tag {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, length = 100)
    private String slug;

    @Column(columnDefinition = "text")
    private String description;

    @Column(length = 20)
    private String color;

    @Column(length = 100)
    private String icon;

    @Column(name = "is_hidden")
    private boolean isHidden;

    @Column(name = "is_restricted")
    private boolean isRestricted;

    @Column(name = "parent_id")
    private Integer parentId;

    @Column(name = "discussion_count")
    private Integer discussionCount = 0;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
