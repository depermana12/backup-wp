#!/usr/bin/env bash

read -p "Enter user@ip: " VPS
REMOTE_DIR=${REMOTE_DIR:-~/wp_backups}

echo "Copying backups from $VPS:$REMOTE_DIR to $(pwd)..."
scp -r "$VPS:$REMOTE_DIR/"* .

if [[ $? -eq 0 ]]; then
  echo "Success"
else
  echo "Failed"
fi
