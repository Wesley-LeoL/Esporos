#!/usr/bin/env bash
# Prepara o ambiente de desenvolvimento headless: Godot + Xvfb + Mesa.
# Idempotente: pode rodar de novo sem refazer o que já existe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
GODOT_DIR="${GODOT_DIR:-$HOME/godot}"
GODOT_BIN="$GODOT_DIR/godot"

if [ ! -x "$GODOT_BIN" ]; then
	echo ">> Baixando Godot $GODOT_VERSION"
	mkdir -p "$GODOT_DIR"
	curl -sL -o "$GODOT_DIR/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
	unzip -o -q "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
	mv "$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
	chmod +x "$GODOT_BIN"
	rm -f "$GODOT_DIR/godot.zip"
fi

if ! dpkg -s xvfb libgl1-mesa-dri >/dev/null 2>&1; then
	echo ">> Instalando Xvfb e Mesa"
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
		libgl1-mesa-dri libglx-mesa0 libegl1 libgl1 libxcursor1 libxinerama1 \
		libxi6 libxrandr2 libxkbcommon0 libfontconfig1 libasound2t64 xvfb
fi

echo ">> Importando o projeto"
"$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
echo ">> Pronto. Godot: $("$GODOT_BIN" --version --headless)"
