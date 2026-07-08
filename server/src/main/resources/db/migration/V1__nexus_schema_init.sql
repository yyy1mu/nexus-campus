-- ============================================================
-- Nexus Campus — Schema Init (Nexus tables only)
-- Generated from Nexus migrations.
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ── Nexus agent_profiles ──
CREATE TABLE IF NOT EXISTS `nexus_agent_profiles` (
  `user_id`                  INT UNSIGNED NOT NULL,
  `agent_name`               VARCHAR(120) NULL,
  `agent_avatar_url`         VARCHAR(512) NULL,
  `soul_md`                  TEXT NULL,
  `interest_tags`            TEXT NULL,
  `skill_tags`               TEXT NULL,
  `help_tags`                TEXT NULL,
  `match_preferences`        TEXT NULL,
  `allow_agent_posting`      TINYINT(1) NOT NULL DEFAULT 0,
  `allow_agent_replying`     TINYINT(1) NOT NULL DEFAULT 0,
  `allow_agent_matching`     TINYINT(1) NOT NULL DEFAULT 0,
  `allow_location_matching`  TINYINT(1) NOT NULL DEFAULT 0,
  `location_visibility`      VARCHAR(40) NOT NULL DEFAULT 'off',
  `created_at`               DATETIME NULL,
  `updated_at`               DATETIME NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus agent_action_logs ──
CREATE TABLE IF NOT EXISTS `nexus_agent_action_logs` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`        INT UNSIGNED NOT NULL,
  `action_type`    VARCHAR(120) NOT NULL,
  `target_type`    VARCHAR(120) NOT NULL,
  `target_id`      INT UNSIGNED NULL,
  `status`         VARCHAR(40) NOT NULL DEFAULT 'succeeded',
  `user_confirmed` TINYINT(1) NOT NULL DEFAULT 0,
  `input_summary`  TEXT NULL,
  `output_summary` TEXT NULL,
  `ip_address`     VARCHAR(45) NULL,
  `created_at`     DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `naal_user_created_idx` (`user_id`, `created_at`),
  INDEX `naal_action_created_idx` (`action_type`, `created_at`),
  INDEX `naal_target_idx` (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus user_capabilities ──
CREATE TABLE IF NOT EXISTS `nexus_user_capabilities` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`           INT UNSIGNED NOT NULL,
  `label`             VARCHAR(80) NOT NULL,
  `name`              VARCHAR(120) NOT NULL,
  `summary`           TEXT NULL,
  `availability`      VARCHAR(80) NULL,
  `service_radius_m`  INT UNSIGNED NULL,
  `is_active`         TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`        DATETIME NULL,
  `updated_at`        DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nuc_user_label_unique` (`user_id`, `label`),
  INDEX `nuc_label_active_idx` (`label`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus user_llm_settings ──
CREATE TABLE IF NOT EXISTS `nexus_user_llm_settings` (
  `user_id`                    INT UNSIGNED NOT NULL,
  `provider`                   VARCHAR(60) NOT NULL DEFAULT 'builtin',
  `base_url`                   VARCHAR(512) NULL,
  `chat_model`                 VARCHAR(120) NULL,
  `responses_model`            VARCHAR(120) NULL,
  `api_key`                    TEXT NULL,
  `supports_chat_completions`  TINYINT(1) NOT NULL DEFAULT 1,
  `supports_responses`         TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`                 DATETIME NULL,
  `updated_at`                 DATETIME NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus help_requests ──
CREATE TABLE IF NOT EXISTS `nexus_help_requests` (
  `id`                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `discussion_id`         INT UNSIGNED NULL,
  `requester_user_id`     INT UNSIGNED NOT NULL,
  `status`                VARCHAR(40) NOT NULL DEFAULT 'open',
  `category_label`        VARCHAR(80) NULL,
  `needed_labels`         TEXT NULL,
  `summary`               TEXT NULL,
  `urgency`               VARCHAR(40) NOT NULL DEFAULT 'normal',
  `location_hint`         VARCHAR(255) NULL,
  `meeting_safety_state`  VARCHAR(40) NOT NULL DEFAULT 'not_arranged',
  `agent_context`         TEXT NULL,
  `created_at`            DATETIME NULL,
  `updated_at`            DATETIME NULL,
  `closed_at`             DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `nhr_status_label_idx` (`status`, `category_label`),
  INDEX `nhr_requester_status_idx` (`requester_user_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus help_matches ──
CREATE TABLE IF NOT EXISTS `nexus_help_matches` (
  `id`                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `help_request_id`       INT UNSIGNED NOT NULL,
  `helper_user_id`        INT UNSIGNED NOT NULL,
  `status`                VARCHAR(40) NOT NULL DEFAULT 'offered',
  `message`               TEXT NULL,
  `meeting_hint`          VARCHAR(255) NULL,
  `meeting_safety_state`  VARCHAR(40) NOT NULL DEFAULT 'not_arranged',
  `created_at`            DATETIME NULL,
  `updated_at`            DATETIME NULL,
  `accepted_at`           DATETIME NULL,
  `completed_at`          DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nhm_request_helper_unique` (`help_request_id`, `helper_user_id`),
  INDEX `nhm_request_status_idx` (`help_request_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus help_dispatches ──
CREATE TABLE IF NOT EXISTS `nexus_help_dispatches` (
  `id`                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `help_request_id`       INT UNSIGNED NOT NULL,
  `requester_user_id`     INT UNSIGNED NOT NULL,
  `helper_user_id`        INT UNSIGNED NOT NULL,
  `match_id`              INT UNSIGNED NULL,
  `status`                VARCHAR(40) NOT NULL DEFAULT 'pending',
  `message`               TEXT NULL,
  `rationale`             TEXT NULL,
  `response_message`      TEXT NULL,
  `meeting_hint`          VARCHAR(255) NULL,
  `meeting_safety_state`  VARCHAR(40) NOT NULL DEFAULT 'not_arranged',
  `expires_at`            DATETIME NULL,
  `responded_at`          DATETIME NULL,
  `created_at`            DATETIME NULL,
  `updated_at`            DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `nhd_request_helper_unique` (`help_request_id`, `helper_user_id`),
  INDEX `nhd_helper_status_idx` (`helper_user_id`, `status`),
  INDEX `nhd_request_status_idx` (`help_request_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus help_match_messages ──
CREATE TABLE IF NOT EXISTS `nexus_help_match_messages` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `match_id`        INT UNSIGNED NOT NULL,
  `user_id`         INT UNSIGNED NOT NULL,
  `content`         TEXT NOT NULL,
  `agent_context`   TEXT NULL,
  `created_at`      DATETIME NULL,
  `updated_at`      DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `nhmm_match_created_idx` (`match_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Nexus device_signals ──
CREATE TABLE IF NOT EXISTS `nexus_device_signals` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`         INT UNSIGNED NOT NULL,
  `purpose`         VARCHAR(80) NOT NULL DEFAULT 'linkgo',
  `coarse_geohash`  VARCHAR(32) NULL,
  `accuracy_m`      INT UNSIGNED NULL,
  `bluetooth_seen`  TINYINT(1) NOT NULL DEFAULT 0,
  `shake_detected`  TINYINT(1) NOT NULL DEFAULT 0,
  `gyro_available`  TINYINT(1) NOT NULL DEFAULT 0,
  `payload`         TEXT NULL,
  `created_at`      DATETIME NULL,
  `expires_at`      DATETIME NULL,
  PRIMARY KEY (`id`),
  INDEX `nds_purpose_created_idx` (`purpose`, `created_at`),
  INDEX `nds_user_created_idx` (`user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
