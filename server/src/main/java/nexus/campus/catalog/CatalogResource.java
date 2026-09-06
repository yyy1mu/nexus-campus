package nexus.campus.catalog;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.BatchSize;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "nexus_catalog_resources", indexes = {
    @Index(name = "idx_catalog_kind_created", columnList = "kind,created_at"),
    @Index(name = "idx_catalog_owner", columnList = "owner_id")
})
@Getter @Setter @NoArgsConstructor
public class CatalogResource {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;
    @Column(name = "owner_id", nullable = false)
    private Integer ownerId;
    @Column(nullable = false, length = 8)
    private String kind;
    @Column(nullable = false, length = 100)
    private String name;
    @Column(nullable = false, length = 40)
    private String category;
    @Column(nullable = false, length = 300)
    private String summary;
    @Column(nullable = false, columnDefinition = "text")
    private String description;
    @Column(name = "source_url", nullable = false, length = 1000)
    private String sourceUrl;
    @Column(name = "install_command", nullable = false, length = 1000)
    private String installCommand;
    @Column(nullable = false, length = 1000)
    private String endpoint;
    @Column(nullable = false, length = 20)
    private String transport;
    @Column(name = "auth_type", nullable = false, length = 20)
    private String authType;
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    @ElementCollection
    @CollectionTable(name = "nexus_catalog_favorites", joinColumns = @JoinColumn(name = "resource_id"),
        uniqueConstraints = @UniqueConstraint(columnNames = {"resource_id", "user_id"}))
    @Column(name = "user_id", nullable = false)
    @BatchSize(size = 32)
    private Set<Integer> favorites = new HashSet<>();
    @PrePersist void create() { createdAt = Instant.now(); updatedAt = createdAt; }
    @PreUpdate void update() { updatedAt = Instant.now(); }
}
