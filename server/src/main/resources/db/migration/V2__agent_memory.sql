-- Nexus Agent long-term memory.
-- Production currently uses Hibernate ddl-auto=update. This file documents the
-- target schema and becomes executable when versioned Flyway migrations are enabled.

CREATE TABLE IF NOT EXISTS `nexus_agent_memories` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`           INT UNSIGNED NOT NULL,
  `kind`              VARCHAR(40) NOT NULL,
  `title`             VARCHAR(160) NOT NULL,
  `content`           TEXT NOT NULL,
  `tags`              TEXT NULL,
  `status`            VARCHAR(24) NOT NULL DEFAULT 'active',
  `importance`        INT NOT NULL DEFAULT 3,
  `pinned`            TINYINT(1) NOT NULL DEFAULT 0,
  `source_type`       VARCHAR(40) NOT NULL DEFAULT 'user',
  `source_ref`        VARCHAR(255) NULL,
  `sensitivity`       VARCHAR(24) NOT NULL DEFAULT 'normal',
  `share_policy`      VARCHAR(32) NOT NULL DEFAULT 'private',
  `valid_from`        DATETIME NULL,
  `expires_at`        DATETIME NULL,
  `last_accessed_at`  DATETIME NULL,
  `access_count`      INT NOT NULL DEFAULT 0,
  `created_at`        DATETIME NULL,
  `updated_at`        DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `nam_user_status_updated_idx` (`user_id`, `status`, `updated_at`),
  INDEX `nam_user_kind_idx` (`user_id`, `kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nexus_match_memory_shares` (
  `id`                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`              INT UNSIGNED NOT NULL,
  `memory_id`             INT UNSIGNED NOT NULL,
  `owner_user_id`         INT UNSIGNED NOT NULL,
  `shared_by_user_id`     INT UNSIGNED NOT NULL,
  `snapshot_kind`         VARCHAR(40) NOT NULL,
  `snapshot_title`        VARCHAR(160) NOT NULL,
  `snapshot_content`      TEXT NOT NULL,
  `snapshot_tags`         TEXT NULL,
  `snapshot_sensitivity`  VARCHAR(24) NOT NULL,
  `created_at`            DATETIME NULL,
  `revoked_at`            DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nmms_match_memory_unique` (`match_id`, `memory_id`),
  INDEX `nmms_match_revoked_idx` (`match_id`, `revoked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
