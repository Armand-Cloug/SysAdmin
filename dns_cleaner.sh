#!/bin/bash

ZONE_DIR="/root/TestSys/"

if [ "$#" -lt 1 ]; then
    echo "Utilisation : $0 <chaine1> [chaine2] [chaine3] ..."
    exit 1
fi

if [ ! -d "$ZONE_DIR" ]; then
    echo "Erreur : le dossier $ZONE_DIR n'existe pas."
    exit 2
fi

declare -A FILE_LINES
declare -A MODIFIED_FILES

echo "🔍 Recherche dans les fichiers de $ZONE_DIR (hors *.save*)"
echo

# Étape 1 : collecte des correspondances
mapfile -t FILES < <(find "$ZONE_DIR" -type f ! -name "*.save*")

for file in "${FILES[@]}"; do
    for query in "$@"; do
        while IFS= read -r match; do
            linenum=$(echo "$match" | cut -d: -f1)
            content=$(echo "$match" | cut -d: -f2-)
            echo "📁 $file"
            echo "🔎 \"$query\" trouvé ligne $linenum : $content"
            FILE_LINES["$file"]+="$linenum"$'\n'
        done < <(grep -ni "$query" "$file")
    done
done

echo
read -p "❓ Confirmer la suppression de toutes ces lignes ? (oui/non) : " confirm
echo

if [[ "$confirm" == "oui" ]]; then
    for file in "${!FILE_LINES[@]}"; do
        TMP_FILE="${file}.tmp"
        cp "$file" "$TMP_FILE"

        echo "${FILE_LINES[$file]}" | sort -rn | uniq | while read -r linenum; do
            if [[ "$linenum" =~ ^[0-9]+$ ]]; then
                sed -i "${linenum}d" "$TMP_FILE"
            fi
        done

        mv "$TMP_FILE" "$file"
        MODIFIED_FILES["$file"]=1
    done

    echo "✅ Suppression terminée."
    echo
    echo "📝 Fichiers modifiés :"
    for f in "${!MODIFIED_FILES[@]}"; do
        echo " - $f"
    done

    echo
    echo "⚠️ N'oublie pas de modifier le SERIAL dans chaque fichier modifié pour assurer la synchronisation avec les slaves."
else
    echo "❌ Opération annulée. Aucune suppression effectuée."
fi
