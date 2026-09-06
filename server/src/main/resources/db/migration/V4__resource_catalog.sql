CREATE TABLE IF NOT EXISTS nexus_catalog_resources (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_id INT NOT NULL,
    kind VARCHAR(8) NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(40) NOT NULL,
    summary VARCHAR(300) NOT NULL,
    description TEXT NOT NULL,
    source_url VARCHAR(1000) NOT NULL,
    install_command VARCHAR(1000) NOT NULL,
    endpoint VARCHAR(1000) NOT NULL,
    transport VARCHAR(20) NOT NULL,
    auth_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    INDEX idx_catalog_kind_created (kind, created_at),
    INDEX idx_catalog_owner (owner_id)
);
CREATE TABLE IF NOT EXISTS nexus_catalog_favorites (
    resource_id INT NOT NULL,
    user_id INT NOT NULL,
    CONSTRAINT uk_catalog_favorite UNIQUE (resource_id, user_id),
    CONSTRAINT fk_catalog_favorite_resource FOREIGN KEY (resource_id)
        REFERENCES nexus_catalog_resources(id) ON DELETE CASCADE
);
