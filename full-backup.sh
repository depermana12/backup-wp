#!/usr/bin/env bash

# ============================================================
# Script Name : full-backup.sh
# Description : Interactive backup script for WordPress sites.
#               Allows user to select one or all WordPress sites
#               in $WORDPRESS_DIR and creates compressed backups
#               in $BACKUP_DIR (default: /backups).
# Owner       : depermana
# Date        : 08-06-2025
# ============================================================

WORDPRESS_DIR="/var/www/"
BACKUP_DIR="/backups"

log_info() {
  echo "[$(date '+%d-%m-%y %H:%M:%S')] [INFO] $1"
}

log_error() {
  echo "[$(date '+%d-%m-%y %H:%M:%S')] [ERROR] $1" >&2
}

log_warning() {
  echo "[$(date '+%d-%m-%y %H:%M:%S')] [WARNING] $1" >&2
}

check_dependencies() {
  local missing_deps=()

  command -v tar >/dev/null 2>&1 || missing_deps+=("tar")
  command -v gzip >/dev/null 2>&1 || missing_deps+=("gzip")

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_error "Please install missing tools and try again."
    exit 1
  fi
}

list_wordpress() {
  local sites=()
  local count=1

  log_info "Scanning for WordPress installations in $WORDPRESS_DIR:"

  for site in "$WORDPRESS_DIR"/*; do
    if [[ -d "$site" && -f "$site/wp-config.php" ]]; then
      sites+=("$(basename "$site")")
      log_info "$count) $(basename "$site")"
      ((count++))
    fi
  done

  if [[ ${#sites[@]} -eq 0 ]]; then
    log_error "No WordPress installations found in $WORDPRESS_DIR"
    exit 1
  fi

  echo "a) All site"
  echo "q) Quit"

  while true; do
    read -p "Select site to backup (number/a/q): " choice
    case $choice in
    [0-9]*)
      if [[ $choice -ge 1 && $choice -le ${#sites[@]} ]]; then
        log_info "Selected: ${sites[$((choice - 1))]}"
        SELECTED_DIRS=("${sites[$((choice - 1))]}")
        break
      else
        log_error "Invalid selection. Please choose 1-${#sites[@]}, or 'a' for all."
      fi
      ;;
    a)
      log_info "Selected: All sites"
      SELECTED_DIRS=("${sites[@]}")
      break
      ;;
    q)
      echo "Exiting"
      exit 0
      ;;
    *)
      log_error "Invalid option. Please select a valid option."
      ;;
    esac
  done
}

backup_wordpress_db() {
  local site="$1"
  local backup_dir="$2"
  local wp_config_file="$WORDPRESS_DIR/$site/wp-config.php"
  local timestamp=$(date +"%d%m%Y_%H%M%S")
  local db_backup_file="$backup_dir/db_${site}_${timestamp}.sql"

  log_info "Starting database backup for $wp_config_file"

  if [[ ! -f "$wp_config_file" ]]; then
    log_error "Failed to extract database configs from $wp_config_file"
    return 1
  fi

  DB_NAME=$(grep "DB_NAME" "$wp_config_file" | cut -d "'" -f 4)
  DB_USER=$(grep "DB_USER" "$wp_config_file" | cut -d "'" -f 4)
  DB_PASSWORD=$(grep "DB_PASSWORD" "$wp_config_file" | cut -d "'" -f 4)
  DB_HOST=$(grep "DB_HOST" "$wp_config_file" | cut -d "'" -f 4)

  if [[ -z "$DB_NAME" || -z "$DB_USER" ]]; then
    log_error "Could not extract database credentials from $wp_config_file"
    return 1
  fi

  if [[ -n $DB_PASSWORD ]]; then
    MYSQL_PWD="$DB_PASSWORD" mysqldump \
      -h "$DB_HOST" \
      -u "$DB_USER" \
      --single-transaction \
      --routines \
      --triggers \
      "$DB_NAME" >"$db_backup_file" 2>/dev/null
  fi

  if [[ $? -eq 0 && -s "$db_backup_file" ]]; then
    local size=$(du -h "$db_backup_file" | cut -f1)
    log_info "Database backup successful: $db_backup_file ($size)"

    gzip "$db_backup_file" 2>/dev/null
    log_info "Compressed database backup: $db_backup_file.gz"
    return 0
  else
    log_error "Database backup failed for $site"
    return 1
  fi

}

backup_wordpress_dir() {
  local site="$1"
  local backup_dir="$2"
  local timestamp=$(date +"%d%m%Y_%H%M%S")
  local site_path="$WORDPRESS_DIR/$site"
  local backup_file="$backup_dir/${site}_${timestamp}.tar.gz"

  log_info "Starting backup for $site"

  if [[ ! -d "$site_path" ]]; then
    log_error "Directory $site_path not found."
    return 1
  fi

  tar -czf "$backup_file" -C "$WORDPRESS_DIR" "$site" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    local size=$(du -h "$backup_file" | cut -f1)
    log_info "Backup successful: $backup_file ($size)"
    return 0
  else
    log_error "Backup failed for $site_path"
    return 1
  fi
}

backup() {
  local site="$1"
  local backup_dir="$2"

  if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
    log_info "Created backup directory: $backup_dir"
  fi

  log_info "=====Starting full backup for $site====="

  backup_wordpress_dir "$site" "$backup_dir"
  local dir_status=$?

  backup_wordpress_db "$site" "$backup_dir"
  local db_status=$?

  if [[ $dir_status -eq 0 && $db_status -eq 0 ]]; then
    log_info "Complete backup successful for $site"
  elif [[ $dir_status -eq 0 && $db_status -ne 0 ]]; then
    log_warning "Files backed up successfully, but database backup failed for $site"
  elif [[ $db_status -eq 0 ]]; then
    log_warning "Database backed up successfully, but file backup failed for $site"
  else
    log_error "Both file and database backup failed for $site"
  fi

  echo "---"
}

main() {
  check_dependencies

  # custom dir if provided
  if [[ -n "$1" ]]; then
    BACKUP_DIR="$1"
  fi

  log_info "WordPress Backup Script Starting"
  log_info "WordPress Directory: $WORDPRESS_DIR"
  log_info "Backup Directory: $BACKUP_DIR"
  echo ""

  list_wordpress

  echo ""
  log_info "Starting backup process..."

  for site in "${SELECTED_DIRS[@]}"; do
    backup "$site" "$BACKUP_DIR"
  done

  log_info "Backup completed. All backups are stored in $BACKUP_DIR"
}

main "$@"
