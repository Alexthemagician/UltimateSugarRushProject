-- iHeartWorld database reconstruction
-- Recreated from the original JPA entities, frontend usage, UML, and StartingScript.sql.
-- MySQL 8.x
--
-- This script is intentionally non-destructive: it does not DROP the database.
-- Run it against an empty server/schema, or review existing tables before importing.

CREATE DATABASE IF NOT EXISTS `i-heart-world`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE `i-heart-world`;

CREATE TABLE IF NOT EXISTS `app_user` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_name` VARCHAR(255) NOT NULL,
  `user_password` VARCHAR(255) NOT NULL,
  `profile_img_url` VARCHAR(2048) NULL,
  `about` TEXT NULL,
  `email` VARCHAR(320) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_app_user_user_name` (`user_name`),
  UNIQUE KEY `uk_app_user_email` (`email`)
) ENGINE=InnoDB;

-- `post_id` is retained as the User relationship column because both UserPost.java
-- and GroupPost.java use @JoinColumn(name = "post_id"). The actual post primary
-- key expected by the entities is `id`.
CREATE TABLE IF NOT EXISTS `user_post` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` VARCHAR(255) NOT NULL,
  `post_category` VARCHAR(255) NULL,
  `post_title` VARCHAR(255) NULL,
  `post_text` TEXT NULL,
  `post_img_url` VARCHAR(2048) NULL,
  `post_video_url` VARCHAR(2048) NULL,
  `date_created` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6),
  `last_updated` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  `post_id` BIGINT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_post_user_id` (`user_id`),
  KEY `idx_user_post_category` (`post_category`),
  KEY `idx_user_post_owner` (`post_id`),
  CONSTRAINT `fk_user_post_owner`
    FOREIGN KEY (`post_id`) REFERENCES `app_user` (`id`)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `group` (
  `group_id` BIGINT NOT NULL AUTO_INCREMENT,
  `group_name` VARCHAR(255) NOT NULL,
  `group_description` TEXT NULL,
  `group_img_url` VARCHAR(2048) NULL,
  `group_admin` VARCHAR(255) NOT NULL,
  `date_created` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6),
  `members` TEXT NULL,
  PRIMARY KEY (`group_id`),
  KEY `idx_group_admin` (`group_admin`),
  CONSTRAINT `fk_group_admin_user_name`
    FOREIGN KEY (`group_admin`) REFERENCES `app_user` (`user_name`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `group_members` (
  `member_id` BIGINT NOT NULL AUTO_INCREMENT,
  `group_id` BIGINT NOT NULL,
  `member_name` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `uk_group_members_group_member` (`group_id`, `member_name`),
  KEY `idx_group_members_member_name` (`member_name`),
  CONSTRAINT `fk_group_members_group`
    FOREIGN KEY (`group_id`) REFERENCES `group` (`group_id`)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_group_members_user_name`
    FOREIGN KEY (`member_name`) REFERENCES `app_user` (`user_name`)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `group_post` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_id` VARCHAR(255) NOT NULL,
  `post_category` VARCHAR(255) NULL,
  `post_title` VARCHAR(255) NULL,
  `post_text` TEXT NULL,
  `post_img_url` VARCHAR(2048) NULL,
  `post_video_url` VARCHAR(2048) NULL,
  `date_created` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6),
  `last_updated` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  `group_id` BIGINT NOT NULL,
  `post_id` BIGINT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_group_post_user_id` (`user_id`),
  KEY `idx_group_post_group_id` (`group_id`),
  KEY `idx_group_post_owner` (`post_id`),
  CONSTRAINT `fk_group_post_group`
    FOREIGN KEY (`group_id`) REFERENCES `group` (`group_id`)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_group_post_owner`
    FOREIGN KEY (`post_id`) REFERENCES `app_user` (`id`)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `messages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `user_name` VARCHAR(255) NOT NULL,
  `message_text` TEXT NOT NULL,
  `date_created` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6),
  `last_updated` DATETIME(6) NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_messages_user_name` (`user_name`),
  KEY `idx_messages_date_created` (`date_created`),
  CONSTRAINT `fk_messages_user_name`
    FOREIGN KEY (`user_name`) REFERENCES `app_user` (`user_name`)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Seed account retained from the original StartingScript.sql.
-- The insert is repeatable and will not overwrite an existing account.
INSERT IGNORE INTO `app_user`
  (`user_name`, `user_password`, `profile_img_url`, `about`)
VALUES
  ('worldmaster', 'masterofpuppets',
   'https://photos.google.com/photo/AF1QipPgIux9oVOI5qnoyt02mxgzCj13tc_lf4RVf6Yb',
   'All things in the universe exist in the universe...or something.');

-- Verification: expect six rows, one for each reconstructed table.
SELECT `table_name`
FROM `information_schema`.`tables`
WHERE `table_schema` = 'i-heart-world'
  AND `table_name` IN
    ('app_user', 'user_post', 'group', 'group_members', 'group_post', 'messages')
ORDER BY `table_name`;
