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
BACKUP_DIR="$HOME/wp_backups"

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_warning() {
  echo "[WARNING] $1" >&2
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

  echo "Scanning WordPress installations"
  echo

  for site in "$WORDPRESS_DIR"/*; do
    if [[ -d "$site" && -f "$site/wp-config.php" ]]; then
      sites+=("$(basename "$site")")
      echo "$count) $(basename "$site")"
      ((count++))
    fi
  done

  echo "a) All site"
  echo "q) Quit"

  while true; do
    read -p "Select site to backup (number/a/q): " choice
    case $choice in
    [0-9]*)
      if [[ $choice -ge 1 && $choice -le ${#sites[@]} ]]; then
        echo "Selected: ${sites[$((choice - 1))]}"
        SELECTED_DIRS=("${sites[$((choice - 1))]}")
        break
      else
        log_error "Invalid selection. Please choose 1-${#sites[@]}, or 'a' for all."
      fi
      ;;
    a)
      echo "Selected: All sites"
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

  echo "Starting database backup for $site"

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
  local backup_file="$backup_dir/${site}_${timestamp}.tar.gz"

  log_info "Starting file backup for $site"

  if tar -czf "$backup_file" -C "$WORDPRESS_DIR" "$site" 2>/dev/null; then
    local size=$(du -h "$backup_file" | cut -f1)
    log_info "File backup successful: $backup_file ($size)"
    return 0
  else
    log_error "File backup failed for $site"
    [[ -f "$backup_file" ]] && rm -f "$backup_file"
    return 1
  fi
}

backup_nginx() {
  local site="$1"
  local backup_dir="$2"
  local timestamp=$(date +"%d%m%Y_%H%M%S")
  local nginx_conf_path="/etc/nginx/sites-available/$site"
  local backup_file="$backup_dir/nginx_${site}_${timestamp}.txt"

  if [[ -f "$nginx_conf_path" ]]; then
    cp "$nginx_conf_path" "$backup_file"
    log_info "Nginx configuration backup successful: $backup_file"
  else
    log_error "Nginx configuration file not found: $nginx_conf_path"
  fi

  return 0
}

backup() {
  local site="$1"
  local backup_dir="$2"

  if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
    echo "Backup directory created: $backup_dir"
  fi

  echo "==========Starting backup for $site=========="

  backup_wordpress_dir "$site" "$backup_dir"
  local dir_status=$?

  backup_wordpress_db "$site" "$backup_dir"
  local db_status=$?

  backup_nginx "$site" "$backup_dir"
  local nginx_status=$?

  if [[ $dir_status -eq 0 && $db_status -eq 0 && $nginx_status -eq 0 ]]; then
    log_info "Complete backup successful for $site"
  elif [[ $dir_status -eq 0 && $db_status -ne 0 && $nginx_status -ne 0 ]]; then
    log_warning "Files backed up successfully, but database and Nginx backup failed for $site"
  elif [[ $db_status -eq 0 ]]; then
    log_warning "Database backed up successfully, but file backup failed for $site"
  else
    log_error "Both file and database backup failed for $site"
  fi

  echo "---"
}

main() {
  echo "          WordPress Backup Script"
  echo "#############################################"

  check_dependencies

  # custom dir if provided
  if [[ -n "$1" ]]; then
    BACKUP_DIR="$1"
  fi

  echo "WordPress directory: $WORDPRESS_DIR"
  echo "Backup directory: $BACKUP_DIR"
  echo ""

  list_wordpress
  echo ""

  for site in "${SELECTED_DIRS[@]}"; do
    backup "$site" "$BACKUP_DIR"
  done

  echo ""
  echo "Backup process completed"
}

main "$@"
