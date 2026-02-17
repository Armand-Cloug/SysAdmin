#!/usr/bin/env bash
set -euo pipefail

# cleanup_nginx_confs.sh
# Usage: sudo ./cleanup_nginx_confs.sh <pattern>
# Example: sudo ./cleanup_nginx_confs.sh montreuil

PATTERN="${1:-}"
if [[ -z "$PATTERN" ]]; then
  echo "Usage: $0 <pattern>"
  exit 1
fi

# Directories to scan
NGINX_DIRS=(/etc/nginx/conf.d/prod /etc/nginx/conf.d/internal /etc/nginx/conf.d/re7)

TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_DIR="/root/nginx_backup_${TIMESTAMP}_${PATTERN}"
mkdir -p "$BACKUP_DIR"

echo "Pattern: '$PATTERN'"
echo "Scanning nginx conf dirs:"
printf " - %s\n" "${NGINX_DIRS[@]}"
echo

# Find matching files (filenames OR file contents), only .conf files
mapfile -t MATCHED_FILES < <(
  for d in "${NGINX_DIRS[@]}"; do
    [[ -d "$d" ]] || continue

    # 1) match in filename
    find "$d" -maxdepth 1 -type f -name "*.conf" -iname "*${PATTERN}*" -print

    # 2) match in content (server_name, cert paths, etc.)
    # Use grep -l to print files that contain the pattern (case-insensitive)
    grep -Irl --include="*.conf" -- "$PATTERN" "$d" 2>/dev/null || true
  done | awk '!seen[$0]++' | sort
)

if [[ ${#MATCHED_FILES[@]} -eq 0 ]]; then
  echo "No nginx .conf files matched pattern '$PATTERN' (by name or content)."
  exit 0
fi

echo "Matched nginx config files:"
echo "------------------------------------------------------------"
for f in "${MATCHED_FILES[@]}"; do
  echo " - $f"
done
echo "------------------------------------------------------------"
echo

echo "Preview (server_name lines) from matched files:"
echo "------------------------------------------------------------"
for f in "${MATCHED_FILES[@]}"; do
  echo ">>> $f"
  grep -nE '^\s*server_name\s+' "$f" || echo "  (no server_name line found)"
  echo
done
echo "------------------------------------------------------------"
echo

read -r -p "Do you want to BACKUP and DELETE these ${#MATCHED_FILES[@]} file(s)? (yes/no): " CONFIRM1
if [[ "$CONFIRM1" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

read -r -p "Type 'DELETE' to confirm permanent deletion: " CONFIRM2
if [[ "$CONFIRM2" != "DELETE" ]]; then
  echo "Aborted."
  exit 0
fi

echo
echo "Backing up to: $BACKUP_DIR"
for d in "${NGINX_DIRS[@]}"; do
  [[ -d "$d" ]] || continue
  mkdir -p "$BACKUP_DIR/$(basename "$d")"
done

echo
echo "Deleting files:"
for f in "${MATCHED_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    subdir="$(basename "$(dirname "$f")")"      # prod / re7 / internal
    cp -a "$f" "$BACKUP_DIR/$subdir/"
    rm -v "$f"
  else
    echo "WARNING: file not found (skipped): $f"
  fi
done

echo
echo "Testing nginx config..."
if nginx -t; then
  echo "nginx -t: OK"
  read -r -p "Reload nginx now? (yes/no): " RELOAD
  if [[ "$RELOAD" == "yes" ]]; then
    systemctl reload nginx && echo "Reloaded." || echo "Reload failed."
  else
    echo "Not reloaded."
  fi
else
  echo "nginx -t: FAILED"
  echo "Restore option:"
  read -r -p "Restore deleted files from backup now? (yes/no): " RESTORE
  if [[ "$RESTORE" == "yes" ]]; then
    for f in "${MATCHED_FILES[@]}"; do
      subdir="$(basename "$(dirname "$f")")"
      base="$(basename "$f")"
      if [[ -f "$BACKUP_DIR/$subdir/$base" ]]; then
        cp -a "$BACKUP_DIR/$subdir/$base" "$(dirname "$f")/"
      fi
    done
    echo "Restored. Re-testing nginx:"
    nginx -t
  else
    echo "Not restored. Backup remains at: $BACKUP_DIR"
  fi
fi

echo
echo "Backup directory: $BACKUP_DIR"
