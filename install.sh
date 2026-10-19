#!/usr/bin/env bash
# husearch kurulum scripti - husearch'i ~/.local/bin altina kurar
set -eu

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.local/bin}"

mkdir -p "$DEST"
install -m 755 "$SRC_DIR/husearch" "$DEST/husearch"
echo "[+] husearch kuruldu: $DEST/husearch"

case ":$PATH:" in
    *":$DEST:"*) ;;
    *) echo "[!] $DEST PATH'inizde degil. Su satiri ~/.bashrc veya ~/.zshrc dosyaniza ekleyin:"
       echo "    export PATH=\"\$PATH:$DEST\"" ;;
esac

echo "[*] Dogrulamak icin: husearch --help"
