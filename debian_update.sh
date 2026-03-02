#!/bin/bash
# =============================================================================
#  debian_update.sh — Mise à jour automatique Debian
#  Usage : ./debian_update.sh           (manuel)
#          via cron : 0 3 * * * /root/scripts/debian_update.sh
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
LOG_DIR="/root/updates"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/Update_${DATE}.log"
LOCK_FILE="/var/run/debian_update.lock"

# ── Couleurs (désactivées si pas de TTY) ──────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# ── Fonctions utilitaires ─────────────────────────────────────────────────────
log() { echo -e "$1" | tee -a "$LOG_FILE"; }
log_only() { echo -e "$1" >> "$LOG_FILE"; }

cleanup() {
    rm -f "$LOCK_FILE"
}

# ── Vérifications préliminaires ───────────────────────────────────────────────
# Root requis
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERREUR]${RESET} Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# Créer le dossier de logs si nécessaire
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    echo "Dossier $LOG_DIR créé."
fi

# Verrou anti-concurrence
if [ -e "$LOCK_FILE" ]; then
    echo -e "${YELLOW}[AVERTISSEMENT]${RESET} Une mise à jour est déjà en cours (lock: $LOCK_FILE). Abandon." >&2
    exit 1
fi
touch "$LOCK_FILE"
trap cleanup EXIT

# ── En-tête du log ────────────────────────────────────────────────────────────
{
echo "============================================================"
echo "  RAPPORT DE MISE À JOUR DEBIAN"
echo "  Date    : $(date '+%A %d %B %Y à %H:%M:%S')"
echo "  Hôte    : $(hostname -f 2>/dev/null || hostname)"
echo "  OS      : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || cat /etc/debian_version)"
echo "  Noyau   : $(uname -r)"
echo "============================================================"
echo ""
} | tee "$LOG_FILE"

# ── Snapshot des versions AVANT ───────────────────────────────────────────────
log "${CYAN}[1/4]${RESET} Capture des versions installées..."
BEFORE_FILE=$(mktemp /tmp/dpkg_before.XXXXXX)
dpkg-query -W -f='${Package} ${Version}\n' > "$BEFORE_FILE" 2>/dev/null
log "      → ${BOLD}$(wc -l < "$BEFORE_FILE")${RESET} paquets recensés."
echo ""

# ── apt-get update ────────────────────────────────────────────────────────────
log "${CYAN}[2/4]${RESET} Mise à jour des listes de paquets (apt-get update)..."
if apt-get update -qq >> "$LOG_FILE" 2>&1; then
    log "      → ${GREEN}OK${RESET}"
else
    log "      → ${RED}ÉCHEC de apt-get update${RESET}"
    rm -f "$BEFORE_FILE"
    exit 2
fi
echo "" | tee -a "$LOG_FILE"

# ── Liste des paquets à mettre à jour ─────────────────────────────────────────
log "${CYAN}[3/4]${RESET} Identification des mises à jour disponibles..."
UPGRADABLE=$(apt-get --simulate --quiet upgrade 2>/dev/null \
    | grep "^Inst " \
    | awk '{print $2}' \
    | sort -u)

NB_UPGRADABLE=$(echo "$UPGRADABLE" | grep -c . || true)

if [ "$NB_UPGRADABLE" -eq 0 ]; then
    log "      → ${GREEN}Aucune mise à jour disponible. Le système est à jour.${RESET}"
    echo ""
    log "============================================================"
    log "  Aucune action effectuée."
    log "============================================================"
    rm -f "$BEFORE_FILE"
    exit 0
fi

log "      → ${BOLD}${NB_UPGRADABLE}${RESET} paquet(s) à mettre à jour."
echo "" | tee -a "$LOG_FILE"

# ── apt-get upgrade ───────────────────────────────────────────────────────────
log "${CYAN}[4/4]${RESET} Application des mises à jour (apt-get upgrade)..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    log "      → ${GREEN}Mise à jour terminée avec succès.${RESET}"
else
    log "      → ${RED}Des erreurs sont survenues pendant la mise à jour (voir détails ci-dessus).${RESET}"
fi
echo "" | tee -a "$LOG_FILE"

# ── Snapshot des versions APRÈS ───────────────────────────────────────────────
AFTER_FILE=$(mktemp /tmp/dpkg_after.XXXXXX)
dpkg-query -W -f='${Package} ${Version}\n' > "$AFTER_FILE" 2>/dev/null

# ── Récapitulatif des changements ─────────────────────────────────────────────
{
echo "============================================================"
echo "  RÉCAPITULATIF DES MISES À JOUR"
echo "============================================================"
echo ""
} | tee -a "$LOG_FILE"

CHANGED=0
while IFS= read -r PKG; do
    BEFORE_VER=$(grep "^${PKG} " "$BEFORE_FILE" | awk '{print $2}')
    AFTER_VER=$(grep  "^${PKG} " "$AFTER_FILE"  | awk '{print $2}')

    if [ -n "$BEFORE_VER" ] && [ -n "$AFTER_VER" ] && [ "$BEFORE_VER" != "$AFTER_VER" ]; then
        CHANGED=$((CHANGED + 1))
        printf "  %-40s %s --> %s\n" "$PKG" "$BEFORE_VER" "$AFTER_VER" | tee -a "$LOG_FILE"
    elif [ -z "$BEFORE_VER" ] && [ -n "$AFTER_VER" ]; then
        CHANGED=$((CHANGED + 1))
        printf "  %-40s %s --> %s\n" "$PKG" "[nouveau]" "$AFTER_VER" | tee -a "$LOG_FILE"
    fi
done <<< "$UPGRADABLE"

echo "" | tee -a "$LOG_FILE"

if [ "$CHANGED" -eq 0 ]; then
    log "  Aucun changement de version détecté."
else
    log "  ${GREEN}${BOLD}${CHANGED} paquet(s) mis à jour.${RESET}"
fi

# ── Paquets orphelins (autoremove) ────────────────────────────────────────────
AUTOREMOVE_LIST=$(apt-get --simulate autoremove 2>/dev/null \
    | grep "^Remv " | awk '{print $2}' | sort -u || true)
NB_AUTOREMOVE=$(echo "$AUTOREMOVE_LIST" | grep -c . || true)

if [ "$NB_AUTOREMOVE" -gt 0 ]; then
    {
    echo ""
    echo "------------------------------------------------------------"
    echo "  PAQUETS ORPHELINS (non supprimés automatiquement)"
    echo "  Lancez 'apt-get autoremove' pour les supprimer."
    echo "------------------------------------------------------------"
    echo "$AUTOREMOVE_LIST" | sed 's/^/  - /'
    } | tee -a "$LOG_FILE"
fi

# ── Reboot requis ? ───────────────────────────────────────────────────────────
{
echo ""
echo "------------------------------------------------------------"
if [ -f /var/run/reboot-required ]; then
    echo "  ⚠  REDÉMARRAGE REQUIS"
    [ -f /var/run/reboot-required.pkgs ] && \
        echo "  Paquets concernés : $(cat /var/run/reboot-required.pkgs | tr '\n' ' ')"
else
    echo "  Pas de redémarrage requis."
fi
echo "------------------------------------------------------------"
echo ""
echo "  Log complet : $LOG_FILE"
echo "  Fin         : $(date '+%d/%m/%Y %H:%M:%S')"
echo "============================================================"
} | tee -a "$LOG_FILE"

# ── Nettoyage ─────────────────────────────────────────────────────────────────
rm -f "$BEFORE_FILE" "$AFTER_FILE"

exit 0
