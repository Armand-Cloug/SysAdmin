# install-node-react-typescript.ps1
# Script d'installation de Node.js (LTS), React et TypeScript sur Windows

Write-Host "=== Installation de NVM pour Windows ==="

$NvmInstaller = "$env:TEMP\nvm-setup.exe"
Invoke-WebRequest -Uri "https://github.com/coreybutler/nvm-windows/releases/download/1.1.12/nvm-setup.exe" -OutFile $NvmInstaller
Start-Process -FilePath $NvmInstaller -Wait

# Ajouter NVM au PATH (dans le cas où ce n’est pas automatique)
$NvmPath = "C:\Program Files\nvm"
if (-Not ($env:PATH -like "*$NvmPath*")) {
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$NvmPath;C:\Program Files\nodejs", [System.EnvironmentVariableTarget]::Machine)
}

Write-Host "=== Installation de Node.js LTS ==="
nvm install lts
nvm use lts

Write-Host "=== Vérification des versions ==="
node -v
npm -v

Write-Host "=== Installation globale de React et TypeScript ==="
npm install -g react react-dom typescript ts-node

Write-Host "=== Vérification des installations ==="
npm list -g --depth=0 | findstr "react typescript"
tsc -v
