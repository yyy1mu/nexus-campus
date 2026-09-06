package nexus.campus.catalog;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
import java.util.Optional;

public interface CatalogRepository extends JpaRepository<CatalogResource, Integer>, JpaSpecificationExecutor<CatalogResource> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from CatalogResource r where r.id = :id")
    Optional<CatalogResource> findLockedById(Integer id);
}
