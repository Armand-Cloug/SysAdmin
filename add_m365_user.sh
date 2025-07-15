#!/bin/bash

# Vérification des droits root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ce script doit être exécuté en tant que root."
  exit 1
fi

# Vérification de l'argument
if [ -z "$1" ]; then
  echo "❌ Usage : $0 adresse_email"
  exit 1
fi

MAIL="$1"
TRANSPORT_FILE="/etc/postfix/transport_m365"
ALIAS_FILE="/etc/postfix/virtual_alias_m365"

# Nom de domaine cible Outlook (modifiable ici si besoin)
OUTLOOK_RELAY=""

# Ajout ou mise à jour dans transport_m365
echo "$MAIL $OUTLOOK_RELAY" >> "$TRANSPORT_FILE"
echo "$MAIL $MAIL" >> "$ALIAS_FILE"

echo "✅ Entrées ajoutées dans les fichiers de transport et alias."

# Suppression des anciens fichiers .db
rm -f "${TRANSPORT_FILE}.db" "${ALIAS_FILE}.db"
echo "🧹 Anciens fichiers .db supprimés."

# Recompilation des fichiers .db
postmap "$TRANSPORT_FILE"
postmap "$ALIAS_FILE"
echo "⚙️  Fichiers .db re-générés."

# Rechargement de Postfix
systemctl reload postfix
echo "🔄 Postfix rechargé avec succès."

echo "✅ L'utilisateur $MAIL est maintenant redirigé vers Microsoft 365."
