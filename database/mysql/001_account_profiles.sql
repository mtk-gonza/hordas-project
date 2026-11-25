CREATE TABLE IF NOT EXISTS account_profiles (
	account_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
	gold BIGINT UNSIGNED NOT NULL DEFAULT 0,
	damage TINYINT UNSIGNED NOT NULL DEFAULT 0,
	health TINYINT UNSIGNED NOT NULL DEFAULT 0,
	speed TINYINT UNSIGNED NOT NULL DEFAULT 0,
	duration TINYINT UNSIGNED NOT NULL DEFAULT 0,
	updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
		ON UPDATE CURRENT_TIMESTAMP(3),
	PRIMARY KEY (account_id),
	CONSTRAINT chk_account_profiles_damage CHECK (damage <= 10),
	CONSTRAINT chk_account_profiles_health CHECK (health <= 10),
	CONSTRAINT chk_account_profiles_speed CHECK (speed <= 10),
	CONSTRAINT chk_account_profiles_duration CHECK (duration <= 10)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
