#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/dontbeskid/iCh3cker/refs/heads/main/iCh3cker.sh"
INSTALL_DIR="/usr/local/bin"
COMMANDS=("iCh3cker" "ichckr" "ichecker")

if command -v curl &>/dev/null; then
    DOWNLOAD_CMD="curl -sSL $SCRIPT_URL -o"
elif command -v wget &>/dev/null; then
    DOWNLOAD_CMD="wget -q $SCRIPT_URL -O"
else
    echo "Error: curl or wget is required."
    exit 1
fi

echo "Installing iCh3cker..."

sudo $DOWNLOAD_CMD "$INSTALL_DIR/${COMMANDS[0]}" || { echo "Download failed."; exit 1; }
sudo chmod +x "$INSTALL_DIR/${COMMANDS[0]}"

for cmd in "${COMMANDS[@]:1}"; do
    sudo ln -sf "$INSTALL_DIR/${COMMANDS[0]}" "$INSTALL_DIR/$cmd"
done

echo "Installation complete. You can now use:"
for cmd in "${COMMANDS[@]}"; do
    echo "  - $cmd"
done
