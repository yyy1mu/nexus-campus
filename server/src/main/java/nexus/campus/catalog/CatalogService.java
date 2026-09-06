package nexus.campus.catalog;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.exception.ApiException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.net.URI;
import java.util.ArrayList;
import java.util.Set;
import jakarta.persistence.criteria.Predicate;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CatalogService {
    private final CatalogRepository repository;

    public CatalogResponse.Listing list(String kind, String q, String scope, String category, int page, Integer viewer) {
        if (!Set.of("skill", "mcp").contains(kind)) throw ApiException.badRequest("kind", "资源类型无效");
        if (!Set.of("all", "mine", "favorites").contains(scope)) throw ApiException.badRequest("scope", "筛选范围无效");
        if (page < 0 || q.length() > 100 || category.length() > 40) throw ApiException.badRequest("query", "查询参数超出范围");
        if (!scope.equals("all")) requireUser(viewer);
        Specification<CatalogResource> spec = (root, query, cb) -> {
            var predicates = new ArrayList<Predicate>();
            predicates.add(cb.equal(root.get("kind"), kind));
            if (!category.isBlank()) predicates.add(cb.equal(root.get("category"), category));
            if (scope.equals("mine")) predicates.add(cb.equal(root.get("ownerId"), viewer));
            if (scope.equals("favorites")) predicates.add(cb.isMember(viewer, root.get("favorites")));
            if (!q.isBlank()) {
                String term = "%" + q.trim().toLowerCase(java.util.Locale.ROOT)
                    .replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
                predicates.add(cb.or(cb.like(cb.lower(root.get("name")), term, '\\'),
                    cb.like(cb.lower(root.get("summary")), term, '\\'),
                    cb.like(cb.lower(root.get("category")), term, '\\')));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        var result = repository.findAll(spec, PageRequest.of(page, 24, Sort.by(Sort.Direction.DESC, "createdAt", "id")));
        return new CatalogResponse.Listing(result.map(r -> CatalogResponse.from(r, viewer)).getContent(),
            result.getTotalElements(), page, result.getTotalPages());
    }

    public CatalogResponse get(Integer id, Integer viewer) {
        return CatalogResponse.from(repository.findById(id).orElseThrow(() -> ApiException.notFound("Resource", id)), viewer);
    }

    @Transactional
    public CatalogResponse save(Integer id, Integer viewer, CatalogRequest input) {
        requireUser(viewer);
        var resource = id == null ? new CatalogResource() : owned(id, viewer);
        if (id != null && !resource.getKind().equals(input.kind()))
            throw ApiException.badRequest("kind", "不能更改资源类型");
        validateUrl(input.sourceUrl(), "sourceUrl");
        if (input.kind().equals("mcp")) {
            if (input.transport().isBlank() || input.authType().isBlank())
                throw ApiException.badRequest("transport", "请选择传输协议和鉴权方式");
            if (input.transport().equals("stdio")) {
                if (input.installCommand().isBlank()) throw ApiException.badRequest("installCommand", "请填写本地启动方式");
                if (!input.authType().equals("none")) throw ApiException.badRequest("authType", "Bearer Token 仅适用于远程 HTTP 服务");
            } else validateUrl(input.endpoint(), "endpoint");
        }
        resource.setOwnerId(viewer);
        resource.setKind(input.kind());
        resource.setName(input.name().trim());
        resource.setCategory(input.category().trim());
        resource.setSummary(input.summary().trim());
        resource.setDescription(input.description().trim());
        resource.setSourceUrl(input.sourceUrl().trim());
        resource.setInstallCommand(input.installCommand().trim());
        boolean mcp = input.kind().equals("mcp");
        resource.setEndpoint(mcp && !input.transport().equals("stdio") ? input.endpoint().trim() : "");
        resource.setTransport(mcp ? input.transport() : "");
        resource.setAuthType(mcp ? input.authType() : "");
        return CatalogResponse.from(repository.saveAndFlush(resource), viewer);
    }

    @Transactional
    public void delete(Integer id, Integer viewer) { requireUser(viewer); repository.delete(owned(id, viewer)); }

    @Transactional
    public CatalogResponse favorite(Integer id, Integer viewer, boolean value) {
        requireUser(viewer);
        var resource = locked(id);
        if (value) resource.getFavorites().add(viewer); else resource.getFavorites().remove(viewer);
        return CatalogResponse.from(resource, viewer);
    }

    private CatalogResource owned(Integer id, Integer viewer) {
        var resource = locked(id);
        if (!resource.getOwnerId().equals(viewer)) throw ApiException.forbidden();
        return resource;
    }
    private CatalogResource locked(Integer id) {
        return repository.findLockedById(id).orElseThrow(() -> ApiException.notFound("Resource", id));
    }
    private void requireUser(Integer viewer) { if (viewer == null) throw ApiException.unauthenticated(); }
    private void validateUrl(String value, String field) {
        try {
            var url = URI.create(value.trim());
            if (!"https".equalsIgnoreCase(url.getScheme()) || url.getHost() == null || url.getUserInfo() != null
                || url.getRawQuery() != null || url.getRawFragment() != null) throw new IllegalArgumentException();
        } catch (IllegalArgumentException e) {
            throw ApiException.badRequest(field, "请使用 HTTPS 地址，不包含账户、Token、查询参数或片段");
        }
    }
}
