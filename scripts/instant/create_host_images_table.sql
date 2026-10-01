CREATE TABLE IF NOT EXISTS host_images (
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  oid INT NOT NULL,
  host INT NOT NULL,
  filename VARCHAR(255) NOT NULL,
  original_filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(64) NOT NULL,
  caption VARCHAR(255),
  inserted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  operated_by INT NOT NULL,
  head ENUM('0','1') NOT NULL DEFAULT '1',
  removed ENUM('0','1') NOT NULL DEFAULT '0',
  INDEX host_images_host_idx (head, removed, host),
  INDEX host_images_oid_idx (oid, head, removed)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
