#!/bin/bash

# Dossier de sortie
OUTPUT_DIR="ps_lxc_outputs"
mkdir -p "$OUTPUT_DIR"

# Récupérer la liste des conteneurs en cours d'exécution
containers=$(lxc list --format csv -c n,s | grep RUNNING | cut -d, -f1)

# Boucle sur chaque conteneur
for c in $containers; do
    echo "📦 Collecte des processus pour le conteneur : $c"
    lxc exec "$c" -- sh -c "hostname; ps aux" > "$OUTPUT_DIR/ps_$c.txt" 2>&1
done

echo "✅ Terminé. Les fichiers sont dans le dossier : $OUTPUT_DIR/"
