#!/usr/bin/env bash
# Renderiza o jogo em uma tela virtual (Xvfb + OpenGL por software) e salva um print.
# Uso: tools/screenshot.sh [saida.png] [--scene=...] [--frames=60] [--hold=move_right:40]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${GODOT_DIR:-$HOME/godot}/godot}"
OUT="${1:-$ROOT/screenshots/shot.png}"
shift || true

# Primeira execução: gera o cache de classes (class_name) e imports.
[ -d "$ROOT/.godot" ] || "$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" \
	"$GODOT_BIN" --path "$ROOT" --rendering-driver opengl3 --resolution 1280x720 \
	--fixed-fps 60 --audio-driver Dummy -s res://tools/screenshot.gd -- --out="$OUT" "$@"
