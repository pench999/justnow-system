#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup_empty_ipaddresses.sh [--dry-run]
  scripts/cleanup_empty_ipaddresses.sh --execute [--yes] [--backup-dir DIR]

Deletes active IPv4 ipaddresses that are all of the following:
  - no hosts
  - holder = false
  - no notes
  - outside every active IPv4 IP segment

Options:
  --dry-run        Show candidate counts only. This is the default.
  --execute        Create a DB backup, then delete matching records.
  --yes            Do not prompt for confirmation when using --execute.
  --backup-dir DIR Backup destination directory. Default: backups
  -h, --help       Show this help.
USAGE
}

mode="dry-run"
yes="false"
backup_dir="backups"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      ;;
    --execute)
      mode="execute"
      ;;
    --yes)
      yes="true"
      ;;
    --backup-dir)
      shift
      if [ "$#" -eq 0 ]; then
        echo "ERROR: --backup-dir requires a value" >&2
        exit 2
      fi
      backup_dir="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$(dirname "$0")/.."

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "ERROR: docker compose or docker-compose is required" >&2
    exit 1
  fi
}

mysql_db() {
  compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"' "$@"
}

candidate_sql() {
  cat <<'SQL'
SELECT COUNT(*) AS cleanup_candidates
FROM ipaddresses ip
WHERE ip.head='1'
  AND ip.removed='0'
  AND ip.version='IPv4'
  AND (ip.hosts IS NULL OR ip.hosts='')
  AND ip.holder='0'
  AND (ip.notes IS NULL OR ip.notes='')
  AND INET_ATON(ip.address) IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM ipsegments seg
    WHERE seg.head='1'
      AND seg.removed='0'
      AND seg.version=ip.version
      AND INET_ATON(seg.address) IS NOT NULL
      AND INET_ATON(ip.address) BETWEEN INET_ATON(seg.address)
        AND INET_ATON(seg.address) + POW(2, 32 - CAST(seg.netmask AS UNSIGNED)) - 1
  );
SQL
}

summary_sql() {
  cat <<'SQL'
SELECT 'ipsegments_active' AS item, COUNT(*) AS cnt
FROM ipsegments
WHERE head='1' AND removed='0';

SELECT 'ipaddresses_active' AS item, COUNT(*) AS cnt
FROM ipaddresses
WHERE head='1' AND removed='0';

SELECT 'ipaddresses_no_host_no_holder_no_notes' AS item, COUNT(*) AS cnt
FROM ipaddresses
WHERE head='1'
  AND removed='0'
  AND (hosts IS NULL OR hosts='')
  AND holder='0'
  AND (notes IS NULL OR notes='');

SELECT 'ipaddresses_no_host_holder' AS item, COUNT(*) AS cnt
FROM ipaddresses
WHERE head='1'
  AND removed='0'
  AND (hosts IS NULL OR hosts='')
  AND holder='1';

SELECT 'ipaddresses_no_host_with_notes' AS item, COUNT(*) AS cnt
FROM ipaddresses
WHERE head='1'
  AND removed='0'
  AND (hosts IS NULL OR hosts='')
  AND (notes IS NOT NULL AND notes<>'');

SELECT 'ipaddresses_with_hosts' AS item, COUNT(*) AS cnt
FROM ipaddresses
WHERE head='1'
  AND removed='0'
  AND hosts IS NOT NULL
  AND hosts<>'';
SQL
}

delete_sql() {
  cat <<'SQL'
DELETE ip
FROM ipaddresses ip
LEFT JOIN ipsegments seg
  ON seg.head='1'
  AND seg.removed='0'
  AND seg.version=ip.version
  AND INET_ATON(seg.address) IS NOT NULL
  AND INET_ATON(ip.address) BETWEEN INET_ATON(seg.address)
    AND INET_ATON(seg.address) + POW(2, 32 - CAST(seg.netmask AS UNSIGNED)) - 1
WHERE ip.head='1'
  AND ip.removed='0'
  AND ip.version='IPv4'
  AND (ip.hosts IS NULL OR ip.hosts='')
  AND ip.holder='0'
  AND (ip.notes IS NULL OR ip.notes='')
  AND INET_ATON(ip.address) IS NOT NULL
  AND seg.oid IS NULL;

SELECT ROW_COUNT() AS deleted_rows;
SQL
}

backup_database() {
  mkdir -p "$backup_dir"
  local backup_file
  backup_file="$backup_dir/yabitz_before_ip_cleanup_$(date +%Y%m%d_%H%M%S).sql.gz"

  echo "Creating backup: $backup_file"
  compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump -uroot --single-transaction --routines --triggers "$MYSQL_DATABASE"' \
    | gzip > "$backup_file"

  gzip -t "$backup_file"
  set +o pipefail
  local first_lines
  first_lines="$(zcat "$backup_file" | head -n 5)"
  set -o pipefail
  if ! printf '%s\n' "$first_lines" | grep -q '^-- MySQL dump'; then
    echo "ERROR: backup does not look like a mysqldump file: $backup_file" >&2
    exit 1
  fi
  ls -lh "$backup_file"
}

echo "== Current summary =="
summary_sql | mysql_db

echo "== Cleanup candidates =="
candidate_sql | mysql_db

if [ "$mode" = "dry-run" ]; then
  echo "Dry-run only. Re-run with --execute to delete candidates."
  exit 0
fi

if [ "$yes" != "true" ]; then
  printf "Type DELETE to continue: "
  read -r answer
  if [ "$answer" != "DELETE" ]; then
    echo "Cancelled."
    exit 0
  fi
fi

backup_database

echo "== Deleting cleanup candidates =="
delete_sql | mysql_db

echo "== Candidates after cleanup =="
candidate_sql | mysql_db

echo "== Summary after cleanup =="
summary_sql | mysql_db
