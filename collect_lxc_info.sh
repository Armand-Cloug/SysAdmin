#!/bin/bash

OUTPUT_DIR="lxc_diagnostics"
mkdir -p "$OUTPUT_DIR"

containers=$(lxc list --format csv -c n,s | grep RUNNING | cut -d, -f1)

for container in $containers; do
  echo "🔍 Collecte pour $container..."

  # Fichier de sortie
  FILE="$OUTPUT_DIR/$container.txt"

  {
    echo "=== $container ==="
    echo
    echo "# 1. Nom d'hôte"
    lxc exec "$container" -- hostname || echo "Non disponible"

    echo
    echo "# 2. Distribution"
    lxc exec "$container" -- cat /etc/os-release 2>/dev/null || echo "Non détecté"

    echo
    echo "# 3. Services actifs (ps aux)"
    lxc exec "$container" -- ps aux || echo "Erreur ps aux"

    echo
    echo "# 4. Dossiers de configuration (/etc)"
    lxc exec "$container" -- ls -lh /etc 2>/dev/null || echo "Accès refusé"

    echo
    echo "# 5. Dossiers de logs (/var/log)"
    lxc exec "$container" -- ls -lh /var/log 2>/dev/null || echo "Accès refusé"

    echo
    echo "# 6. Ports écoutés (ss ou netstat)"
    lxc exec "$container" -- sh -c "ss -tuln || netstat -tuln" || echo "Non disponible"

    echo
    echo "# 7. Top processus (tri CPU)"
    lxc exec "$container" -- ps aux --sort=-%cpu | head -n 15 || echo "Erreur tri CPU"

    echo
    echo "# 8. Top processus (tri MEM)"
    lxc exec "$container" -- ps aux --sort=-%mem | head -n 15 || echo "Erreur tri MEM"
  } > "$FILE"

done

echo "✅ Toutes les infos sont dans le dossier : $OUTPUT_DIR/"
