package nexus.campus.catalog;

import jakarta.validation.constraints.*;

public record CatalogRequest(
    @NotBlank @Pattern(regexp = "skill|mcp") String kind,
    @NotBlank @Size(max = 100) String name,
    @NotBlank @Size(max = 40) String category,
    @NotBlank @Size(max = 300) String summary,
    @NotNull @Size(max = 12000) String description,
    @NotBlank @Size(max = 1000) String sourceUrl,
    @NotNull @Size(max = 1000) String installCommand,
    @NotNull @Size(max = 1000) String endpoint,
    @NotNull @Pattern(regexp = "|streamable-http|sse|stdio") String transport,
    @NotNull @Pattern(regexp = "|none|bearer") String authType
) {}
