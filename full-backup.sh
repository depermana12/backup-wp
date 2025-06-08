#!/bin/bash

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

list_wordpress(){
  log_info "Available WordPress site in $WORDPRESS_DIR:"
  local sites=()
  local count=1

  for site in "$WORDPRESS_DIR"/*; do
    if [[ -d "$site" && -f "$site/wp-config.php" ]]; then
      sites+=("$(basename "$site")")
      echo "$count) $(basename "$site")"
      ((count++))
    fi
  done

  if [[ ${#sites[@]} -eq 0 ]]; then
    echo "No WordPress installations found in $WORDPRESS_DIR"
    exit 1
  fi

  echo "a) All site"
  echo "q) Quit"


  while true; do
    read -p "Select site to backup (number/a/q): " choice
    case $choice in
      [0-9]*)
        if [[ $choice -ge 1 && $choice -le ${#sites[@]} ]]; then
          echo "Selected: ${sites[$((choice-1))]}"
          SELECTED_DIRS="${sites[$((choice-1))]}"
          break
        else
          echo "Invalid. Please select a valid option."
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
        log_error "Invalid. Please select a valid option."
        ;;
    esac
  done
}

backup(){
  local site="$1"
  local backup_dir="$2"

  if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
    echo "Created backup directory: $backup_dir"
  fi

  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local site_path="$WORDPRESS_DIR/$site"
  local backup_file="$backup_dir/${site}_${timestamp}.tar.gz"

  echo "Starting backup for $site"

  echo "Starting backup for $site_path"
  if [[ ! -d "$site_path" ]]; then
    echo "Directory $site_path not found. Exiting."
    return 1
  fi

  tar -czf "$backup_file" -C "$WORDPRESS_DIR" "$site" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    local size=$(du -h "$backup_file" | cut -f1)
    echo "Backup successful: $backup_file ($size)"
  else
    echo "Backup failed for $site_path"
    return 1
  fi
}

main(){
  # custom dir if provided
  if[[ -n "$1" ]]; then
    BACKUP_DIR="$1"
  fi

  list_wordpress

  for site in "${SELECTED_DIRS[@]}"; do
    backup "$site" "$BACKUP_DIR"
  done

  echo "Backup completed. All backups are stored in $BACKUP_DIR"
  
}

main "$@"