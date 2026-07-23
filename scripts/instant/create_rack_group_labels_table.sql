CREATE TABLE IF NOT EXISTS rack_group_labels (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
prefix      VARCHAR(16)     NOT NULL,
display_name VARCHAR(64)    DEFAULT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0',
KEY rack_group_labels_prefix_idx (head, removed, prefix)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
