-- Match collaboration workspace: shared tasks, human decision gates,
-- deliverable handoff, and an append-only event timeline for accepted matches.
-- Production currently uses Hibernate ddl-auto=update. This file documents the
-- target schema and becomes executable when versioned Flyway migrations are enabled.

ALTER TABLE `nexus_help_matches`
  ADD COLUMN `collab_state` VARCHAR(16) NOT NULL DEFAULT 'active',
  ADD COLUMN `baton_role`   VARCHAR(16) NULL;

ALTER TABLE `nexus_help_match_messages`
  ADD COLUMN `kind`              VARCHAR(30) NOT NULL DEFAULT 'chat',
  ADD COLUMN `client_request_id` VARCHAR(80) NULL,
  ADD UNIQUE INDEX `nhmm_match_client_request_uq` (`match_id`, `client_request_id`);

CREATE TABLE IF NOT EXISTS `nexus_match_tasks` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`           INT UNSIGNED NOT NULL,
  `created_by_user_id` INT UNSIGNED NOT NULL,
  `owner_role`         VARCHAR(16) NOT NULL,
  `title`              VARCHAR(160) NOT NULL,
  `note`               TEXT NULL,
  `status`             VARCHAR(16) NOT NULL DEFAULT 'todo',
  `blocked_reason`     VARCHAR(500) NULL,
  `order_index`        INT NOT NULL DEFAULT 0,
  `client_request_id`  VARCHAR(80) NULL,
  `created_at`         DATETIME NULL,
  `updated_at`         DATETIME NULL,
  `done_at`            DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nmt_match_client_request_uq` (`match_id`, `client_request_id`),
  INDEX `nmt_match_order_idx` (`match_id`, `order_index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nexus_match_decisions` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`           INT UNSIGNED NOT NULL,
  `raised_by_user_id`  INT UNSIGNED NOT NULL,
  `raised_by_role`     VARCHAR(16) NOT NULL,
  `assigned_role`      VARCHAR(16) NOT NULL,
  `title`              VARCHAR(200) NOT NULL,
  `context`            TEXT NULL,
  `options_json`       TEXT NOT NULL,
  `status`             VARCHAR(16) NOT NULL DEFAULT 'open',
  `decided_option_key` VARCHAR(80) NULL,
  `decision_note`      VARCHAR(1000) NULL,
  `decided_by_user_id` INT UNSIGNED NULL,
  `decided_at`         DATETIME NULL,
  `client_request_id`  VARCHAR(80) NULL,
  `created_at`         DATETIME NULL,
  `updated_at`         DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nmd_match_client_request_uq` (`match_id`, `client_request_id`),
  INDEX `nmd_match_status_idx` (`match_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nexus_match_deliverables` (
  `id`                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`             INT UNSIGNED NOT NULL,
  `submitted_by_user_id` INT UNSIGNED NOT NULL,
  `submitter_role`       VARCHAR(16) NOT NULL,
  `title`                VARCHAR(200) NOT NULL,
  `description`          TEXT NULL,
  `access_hint`          VARCHAR(500) NULL,
  `checksum`             VARCHAR(128) NULL,
  `license_note`         VARCHAR(500) NULL,
  `status`               VARCHAR(16) NOT NULL DEFAULT 'submitted',
  `review_note`          VARCHAR(1000) NULL,
  `reviewed_by_user_id`  INT UNSIGNED NULL,
  `reviewed_at`          DATETIME NULL,
  `client_request_id`    VARCHAR(80) NULL,
  `created_at`           DATETIME NULL,
  `updated_at`           DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nmdl_match_client_request_uq` (`match_id`, `client_request_id`),
  INDEX `nmdl_match_status_idx` (`match_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `nexus_match_events` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`      INT UNSIGNED NOT NULL,
  `actor_user_id` INT UNSIGNED NULL,
  `actor_role`    VARCHAR(16) NULL,
  `event_type`    VARCHAR(60) NOT NULL,
  `ref_type`      VARCHAR(30) NULL,
  `ref_id`        INT UNSIGNED NULL,
  `summary`       VARCHAR(500) NOT NULL,
  `created_at`    DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_match_events_match_id_id` (`match_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
