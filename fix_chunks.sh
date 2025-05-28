#!/bin/bash

# === Configuration ===
BASE_DIR="/mnt/datastore/DIRXFS/PVE-VMS/.chunks"
OWNER="backup:backup"
PERMISSIONS="750"

echo "🔄 Vérification et création des répertoires chunks de 0000 à ffff…"

for i in $(seq 0 255); do
  for j in $(seq 0 255); do
    HEX_DIR=$(printf "%02x%02x" "$i" "$j")
    DIR_PATH="$BASE_DIR/$HEX_DIR"

    if [ ! -d "$DIR_PATH" ]; then
      mkdir -p "$DIR_PATH"
      chown "$OWNER" "$DIR_PATH"
      chmod "$PERMISSIONS" "$DIR_PATH"
      echo "✅ Créé : $DIR_PATH"
    fi
  done
done

echo "✅ Tous les dossiers de chunks (0000 à ffff) sont présents et sécurisés."
