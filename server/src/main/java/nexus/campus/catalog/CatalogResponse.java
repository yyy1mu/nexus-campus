package nexus.campus.catalog;

import java.time.Instant;
import java.util.List;

public record CatalogResponse(
    Integer id, Integer ownerId, String kind, String name, String category, String summary,
    String description, String sourceUrl, String installCommand, String endpoint,
    String transport, String authType, int favoriteCount, boolean favorited, boolean editable,
    Instant createdAt, Instant updatedAt
) {
    static CatalogResponse from(CatalogResource r, Integer viewer) {
        return new CatalogResponse(r.getId(), r.getOwnerId(), r.getKind(), r.getName(), r.getCategory(),
            r.getSummary(), r.getDescription(), r.getSourceUrl(), r.getInstallCommand(), r.getEndpoint(),
            r.getTransport(), r.getAuthType(), r.getFavorites().size(), r.getFavorites().contains(viewer),
            r.getOwnerId().equals(viewer), r.getCreatedAt(), r.getUpdatedAt());
    }
    public record Listing(List<CatalogResponse> items, long total, int page, int totalPages) {}
}
