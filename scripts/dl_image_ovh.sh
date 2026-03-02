#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Variables obligatoires (à adapter ou passer par l’environnement)
################################################################################
IMAGE_ID=""
DESTINATION=""

################################################################################
# Région : 1er argument > $OS_REGION_NAME > défaut = GRA3
################################################################################
REGION="${1:-${OS_REGION_NAME:-GRA3}}"

################################################################################
# Fonctions utilitaires
################################################################################
ERROR() { echo "[ERREUR] $1" >&2; exit 1; }

################################################################################
# Prérequis jq
################################################################################
command -v jq >/dev/null 2>&1 || ERROR "Le paquet 'jq' est requis (apt install jq)"

################################################################################
# Récupération du token
################################################################################
echo "[INFO] Récupération du token OpenStack..."
TOKEN=$(openstack token issue -f value -c id) || ERROR "Impossible de récupérer le token"

################################################################################
# Recherche de l’endpoint Glance pour la région choisie
################################################################################
echo "[INFO] Recherche de l’endpoint Glance pour ${REGION}…"
GLANCE_URL=$(openstack catalog show image -f json \
            | jq -r --arg REGION "$REGION" '.endpoints[]
                   | select(.interface=="public" and .region==$REGION)
                   | .url' | head -n1)

[ -z "$GLANCE_URL" ] && ERROR "Aucun endpoint « image » trouvé pour la région ${REGION}"

################################################################################
# Téléchargement de l’image
################################################################################
IMAGE_URL="${GLANCE_URL%/}/v2/images/${IMAGE_ID}/file"
echo "[INFO] Téléchargement de l’image (${IMAGE_ID}) depuis ${REGION}…"
curl -sSL -H "X-Auth-Token: $TOKEN" "$IMAGE_URL" -o "$DESTINATION" \
  || ERROR "Échec du téléchargement via curl"

################################################################################
# Vérification du checksum
################################################################################
echo "[INFO] Vérification du checksum…"
CHECKSUM_ATTENDU=$(openstack image show "$IMAGE_ID" -f value -c checksum) \
  || ERROR "Impossible d’obtenir le checksum attendu"

CHECKSUM_OBTENU=$(md5sum "$DESTINATION" | cut -d' ' -f1)

[ "$CHECKSUM_ATTENDU" != "$CHECKSUM_OBTENU" ] \
  && ERROR "Checksum invalide ! Attendu : $CHECKSUM_ATTENDU | Obtenu : $CHECKSUM_OBTENU"

echo "[OK] Image téléchargée et vérifiée avec succès : $DESTINATION"
exit 0
