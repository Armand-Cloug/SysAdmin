#!/usr/bin/env bash
set -euo pipefail

DIR="/var/log/nginx"
N=50

usage() {
  cat <<'EOF'
Usage: oldest_nginx_logs.sh [-n N] [-d DIR]

  -n N    Nombre de fichiers à afficher (défaut: 50)
  -d DIR  Dossier à analyser (défaut: /var/log/nginx)

Affiche les N fichiers .gz les plus vieux (mtime). Propose ensuite une suppression.
EOF
}

while getopts ":n:d:h" opt; do
  case "$opt" in
    n) N="$OPTARG" ;;
    d) DIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Option invalide: -$OPTARG" >&2; usage; exit 2 ;;
    :)  echo "Option -$OPTARG requiert un argument" >&2; usage; exit 2 ;;
  esac
done

if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -le 0 ]]; then
  echo "Erreur: -n doit être un entier > 0" >&2
  exit 2
fi

if [[ ! -d "$DIR" ]]; then
  echo "Erreur: dossier introuvable: $DIR" >&2
  exit 1
fi

# Format tabulé: epoch<TAB>date-heure<TAB>taille<TAB>chemin
mapfile -t LINES < <(
  find "$DIR" -maxdepth 1 -type f -name '*.gz' \
    -printf '%T@\t%TY-%Tm-%Td %TH:%TM:%TS\t%s\t%p\n' 2>/dev/null \
  | sort -n \
  | head -n "$N"
)

if [[ "${#LINES[@]}" -eq 0 ]]; then
  echo "Aucun fichier .gz trouvé dans $DIR"
  exit 0
fi

echo "Les ${#LINES[@]} fichiers .gz les plus vieux (mtime) dans $DIR :"
printf "%-4s %-19s %-12s %s\n" "N°" "DATE" "TAILLE" "FICHIER"

i=0
for line in "${LINES[@]}"; do
  ((++i))
  IFS=$'\t' read -r epoch datetime size path <<<"$line"
  printf "%-4s %-19s %-12s %s\n" "$i" "$datetime" "$size" "$path"
done

echo
read -r -p "Supprimer ces ${#LINES[@]} fichiers ? (oui/non) " ans
case "${ans,,}" in
  oui|o|yes|y)
    echo "Suppression..."
    for line in "${LINES[@]}"; do
      IFS=$'\t' read -r epoch datetime size path <<<"$line"
      rm -f -- "$path"
    done
    echo "Terminé."
    ;;
  *)
    echo "Aucune suppression."
    ;;
esac
