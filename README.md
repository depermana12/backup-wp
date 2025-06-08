## Quick Start

```bash
# download and execute the script
curl -sO https://raw.githubusercontent.com/depermana12/backup-wp/refs/heads/main/full-backup.sh
chmod +x full-backup.sh
./full-backup.sh

# or install system wide
sudo curl -o /usr/local/bin/wp-backup https://raw.githubusercontent.com/depermana12/backup-wp/refs/heads/main/full-backup.sh
sudo chmod +x /usr/local/bin/wp-backup
wp-backup
```

## Usage

```bash
# basic usage
./full-backup.sh

# with custom backup directory
./full-backup.sh /path/to/custom/backup/directory
```
