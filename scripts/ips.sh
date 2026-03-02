#!/bin/bash

# === Analyse des IPs dans un fichier de logs Nginx ===
# Utilisation :
#   ./analyze_ips.sh test.access.log.1.gz
# ou :
#   ./analyze_ips.sh test.access.log

LOGFILE="$1"

if [ -z "$LOGFILE" ]; then
  echo "Usage: $0 <fichier_log_ou_gz>"
  exit 1
fi

# Vérifie si le fichier est compressé (.gz)
if [[ "$LOGFILE" == *.gz ]]; then
  echo "Lecture du fichier compressé : $LOGFILE"
  zcat "$LOGFILE" | awk '{print $1}' | sort | uniq -c | sort -nr
else
  echo "Lecture du fichier : $LOGFILE"
  awk '{print $1}' "$LOGFILE" | sort | uniq -c | sort -nr
fi
