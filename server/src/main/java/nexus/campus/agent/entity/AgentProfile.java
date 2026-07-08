package nexus.campus.agent.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import nexus.campus.common.entity.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "nexus_agent_profiles")
@Getter @Setter @NoArgsConstructor
public class AgentProfile {
    @Id
    @Column(name = "user_id")
    private Integer userId;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", insertable = false, updatable = false)
    private User user;

    @Column(name = "agent_name", length = 120)
    private String agentName;

    @Column(name = "agent_avatar_url", length = 512)
    private String agentAvatarUrl;

    @Column(name = "soul_md", columnDefinition = "text")
    private String soulMd;

    @Column(name = "interest_tags", columnDefinition = "text")
    private String interestTags;

    @Column(name = "skill_tags", columnDefinition = "text")
    private String skillTags;

    @Column(name = "help_tags", columnDefinition = "text")
    private String helpTags;

    @Column(name = "match_preferences", columnDefinition = "text")
    private String matchPreferences;

    @Column(name = "allow_agent_posting")
    private boolean allowAgentPosting;

    @Column(name = "allow_agent_replying")
    private boolean allowAgentReplying;

    @Column(name = "allow_agent_matching")
    private boolean allowAgentMatching;

    @Column(name = "allow_location_matching")
    private boolean allowLocationMatching;

    @Column(name = "location_visibility", length = 40)
    private String locationVisibility = "off";

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); updatedAt = LocalDateTime.now(); }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }
}
