package nexus.campus.catalog;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/nexus/resources")
@RequiredArgsConstructor
public class CatalogController {
    private final CatalogService service;
    @GetMapping
    public ApiResponse<CatalogResponse.Listing> list(@RequestParam(defaultValue = "skill") String kind,
        @RequestParam(defaultValue = "") String q, @RequestParam(defaultValue = "all") String scope,
        @RequestParam(defaultValue = "") String category, @RequestParam(defaultValue = "0") int page, @AuthenticationPrincipal User user) {
        return ApiResponse.ok(service.list(kind, q, scope, category, page, viewer(user)));
    }
    @GetMapping("/{id}")
    public ApiResponse<CatalogResponse> show(@PathVariable Integer id, @AuthenticationPrincipal User user) {
        return ApiResponse.ok(service.get(id, viewer(user)));
    }
    @PostMapping
    public ApiResponse<CatalogResponse> create(@Valid @RequestBody CatalogRequest input, @AuthenticationPrincipal User user) {
        return ApiResponse.ok(service.save(null, viewer(user), input));
    }
    @PutMapping("/{id}")
    public ApiResponse<CatalogResponse> update(@PathVariable Integer id, @Valid @RequestBody CatalogRequest input,
        @AuthenticationPrincipal User user) { return ApiResponse.ok(service.save(id, viewer(user), input)); }
    @DeleteMapping("/{id}")
    public ApiResponse<Boolean> delete(@PathVariable Integer id, @AuthenticationPrincipal User user) {
        service.delete(id, viewer(user)); return ApiResponse.ok(true);
    }
    @PutMapping("/{id}/favorite")
    public ApiResponse<CatalogResponse> favorite(@PathVariable Integer id, @AuthenticationPrincipal User user) {
        return ApiResponse.ok(service.favorite(id, viewer(user), true));
    }
    @DeleteMapping("/{id}/favorite")
    public ApiResponse<CatalogResponse> unfavorite(@PathVariable Integer id, @AuthenticationPrincipal User user) {
        return ApiResponse.ok(service.favorite(id, viewer(user), false));
    }
    private Integer viewer(User user) { return user == null ? null : user.getId(); }
}
