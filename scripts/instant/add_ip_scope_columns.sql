SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE ipsegments ADD COLUMN scope VARCHAR(64) NOT NULL DEFAULT \'default\' AFTER address',
    'SELECT \'ipsegments.scope already exists\''
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ipsegments' AND COLUMN_NAME = 'scope'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE ipaddresses ADD COLUMN scope VARCHAR(64) NOT NULL DEFAULT \'default\' AFTER address',
    'SELECT \'ipaddresses.scope already exists\''
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ipaddresses' AND COLUMN_NAME = 'scope'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE ipsegments ADD INDEX ipsegments_scope_address_idx (scope, address)',
    'SELECT \'ipsegments_scope_address_idx already exists\''
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ipsegments' AND INDEX_NAME = 'ipsegments_scope_address_idx'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE ipaddresses ADD INDEX ipaddresses_scope_address_idx (scope, address)',
    'SELECT \'ipaddresses_scope_address_idx already exists\''
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ipaddresses' AND INDEX_NAME = 'ipaddresses_scope_address_idx'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
