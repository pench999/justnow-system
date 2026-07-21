-- Add optional off-rack location text to hosts.
SET @exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'hosts'
    AND COLUMN_NAME = 'location'
);

SET @stmt := IF(
  @exists = 0,
  'ALTER TABLE hosts ADD COLUMN location VARCHAR(128) NULL AFTER rackunit',
  'SELECT 1'
);

PREPARE stmt FROM @stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
