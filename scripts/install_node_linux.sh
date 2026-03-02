#!/usr/bin/env bash
# install-node-react-typescript.sh
# Installe Node.js (LTS), npm, puis React et TypeScript globalement

set -euo pipefail

echo "=== Mise à jour du système ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Installation de curl et build tools si nécessaire ==="
sudo apt install -y curl build-essential

echo "=== Installation de Node.js LTS via NodeSource ==="
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

echo "=== Vérification des versions installées ==="
node -v
npm -v

echo "=== Installation de React et TypeScript globalement ==="
sudo npm install -g react react-dom typescript ts-node

echo "=== Vérification des installations ==="
npm list -g --depth=0 | grep -E "react|typescript"
tsc -v || echo "TypeScript non trouvé"
