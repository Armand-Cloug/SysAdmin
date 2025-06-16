#!/bin/bash

# === Dossiers ===
PROD_DIR="/etc/nginx/cond.d/prod"
RE7_DIR="/etc/nginx/cond.d/re7"
TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_DIR="/root/nginx_backup_$TIMESTAMP"
mkdir -p "$BACKUP_DIR/prod" "$BACKUP_DIR/re7"

# === Liste exacte des fichiers à supprimer ===
declare -A FILES_TO_DELETE

# --- PROD ---
for f in \
# Liste des fichiers à supprimer
do
  FILES_TO_DELETE["$PROD_DIR/$f"]="prod"
done

# --- RE7 ---
for f in \
# Liste des fichiers à supprimer
do
  FILES_TO_DELETE["$RE7_DIR/$f"]="re7"
done

# === Confirmation ===
echo "🛑 ATTENTION : Ce script va supprimer précisément les fichiers suivants :"
for path in "${!FILES_TO_DELETE[@]}"; do
  echo "  - $path"
done

echo ""
read -p "❓ Voulez-vous continuer ? (oui/non) : " CONFIRM1
if [[ "$CONFIRM1" != "oui" ]]; then
  echo "❌ Opération annulée."
  exit 1
fi

read -p "⚠️ Confirmer la suppression définitive ? (oui/non) : " CONFIRM2
if [[ "$CONFIRM2" != "oui" ]]; then
  echo "❌ Opération annulée."
  exit 1
fi

# === Sauvegarde & Suppression ===
echo ""
for filepath in "${!FILES_TO_DELETE[@]}"; do
  subdir=${FILES_TO_DELETE["$filepath"]}
  if [ -f "$filepath" ]; then
    cp "$filepath" "$BACKUP_DIR/$subdir/"
    rm -v "$filepath"
  else
    echo "⚠️ Fichier introuvable : $filepath"
  fi
done

# === Vérification de la config Nginx ===
echo ""
echo "🧪 Test de configuration Nginx..."
if nginx -t; then
  echo "✅ La configuration Nginx est valide."
  read -p "🔄 Souhaitez-vous recharger Nginx maintenant ? (oui/non) : " RELOAD
  if [[ "$RELOAD" == "oui" ]]; then
    systemctl reload nginx && echo "✅ Nginx rechargé." || echo "❌ Échec du rechargement."
  else
    echo "ℹ️ Nginx **n'a pas été rechargé**."
  fi
else
  echo "❌ Erreur de configuration détectée !"
  read -p "🔁 Voulez-vous restaurer les fichiers supprimés ? (oui/non) : " RESTORE
  if [[ "$RESTORE" == "oui" ]]; then
    cp "$BACKUP_DIR/prod/"* "$PROD_DIR/" 2>/dev/null
    cp "$BACKUP_DIR/re7/"* "$RE7_DIR/" 2>/dev/null
    echo "♻️ Fichiers restaurés depuis la sauvegarde."
    echo "🧪 Nouvelle vérification de Nginx..."
    nginx -t
  else
    echo "⚠️ Les fichiers n'ont pas été restaurés."
  fi
fi

echo ""
echo "📦 Sauvegarde complète : $BACKUP_DIR"
