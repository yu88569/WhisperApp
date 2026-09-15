#!/bin/bash
# install.sh — Installs Whisper AI Dictation for Omarchy Linux
# Sets up Quickshell plugin, CLI symlink, Hyprland keybindings, and bar layout.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="yux.whisper"
USER_PLUGINS_DIR="$HOME/.config/omarchy/plugins"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS_LUA="$HOME/.config/hypr/bindings.lua"

echo "=== Whisper Dictation Installer for Omarchy ==="

# 1. Check prerequisites
echo "Checking prerequisites..."
for tool in pw-record wl-copy wtype hyprctl python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "⚠️  Warning: '$tool' not found on PATH. Please ensure it is installed."
  fi
done

# 2. Symlink plugin to ~/.config/omarchy/plugins/yux.whisper
echo "Linking Omarchy plugin..."
mkdir -p "$USER_PLUGINS_DIR"
rm -rf "$USER_PLUGINS_DIR/$PLUGIN_ID"
ln -sf "$SCRIPT_DIR" "$USER_PLUGINS_DIR/$PLUGIN_ID"
echo "  -> Linked: $USER_PLUGINS_DIR/$PLUGIN_ID"

# 3. Symlink whisper-ctl to ~/.local/bin/whisper-ctl
echo "Linking CLI tool..."
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/whisper-ctl" "$HOME/.local/bin/whisper-ctl"
echo "  -> Linked: $HOME/.local/bin/whisper-ctl"

# 4. Configure Omarchy top bar (shell.json)
if [[ -f "$SHELL_CONFIG" ]]; then
  echo "Updating Omarchy shell.json layout..."
  cp "$SHELL_CONFIG" "$SHELL_CONFIG.bak.$(date +%s)"
  
  python3 - <<EOF
import json
from pathlib import Path

config_path = Path("$SHELL_CONFIG")
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

layout = cfg.setdefault("bar", {}).setdefault("layout", {})
center = layout.setdefault("center", [])

# Check if already added
exists = any(isinstance(w, dict) and w.get("id") == "$PLUGIN_ID" for w in center)
if not exists:
    center.append({"id": "$PLUGIN_ID"})
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    print("  -> Added $PLUGIN_ID to Omarchy center bar.")
else:
    print("  -> $PLUGIN_ID already present in bar layout.")
EOF
fi

# 5. Add Hyprland keybindings
if [[ -f "$BINDINGS_LUA" ]]; then
  echo "Configuring Hyprland keybindings in bindings.lua..."
  if ! grep -q "whisper-ctl" "$BINDINGS_LUA"; then
    cp "$BINDINGS_LUA" "$BINDINGS_LUA.bak.$(date +%s)"
    cat <<'EOF' >> "$BINDINGS_LUA"

-- Whisper AI Dictation (Dual-mode Hold-to-Talk and Tap-to-Toggle)
o.bind("SUPER + H", "Whisper Dictation (Press)", "whisper-ctl key-down")
o.bind("SUPER + H", "Whisper Dictation (Release)", "whisper-ctl key-up", { release = true })
o.bind("SUPER + ALT + ESCAPE", "Whisper Dictation (Cancel)", "whisper-ctl cancel")
EOF
    echo "  -> Added SUPER + H and SUPER + ESC keybindings."
  else
    echo "  -> whisper-ctl keybindings already present in bindings.lua."
  fi

  # Validate Hyprland config
  if command -v hyprctl >/dev/null 2>&1; then
    echo "Validating Hyprland configuration..."
    hyprctl reload || true
    errors="$(hyprctl configerrors 2>&1 || true)"
    if [[ -n "$errors" && "$errors" != *"ok"* && "$errors" != *"no error"* ]]; then
      echo "⚠️  Hyprland config warning: $errors"
    else
      echo "  -> Hyprland config validated successfully."
    fi
  fi
fi

# 6. Restart Omarchy Shell to register the new plugin
if command -v omarchy >/dev/null 2>&1; then
  echo "Reloading Omarchy Shell..."
  omarchy restart shell || true
fi

echo "=== Installation Completed Successfully! ==="
echo ""
echo "Getting Started:"
echo "1. Set your Groq API key: whisper-ctl set-key <YOUR_GROQ_API_KEY>"
echo "   (or click the Whisper mic icon on the Omarchy top bar)"
echo "2. Hold SUPER + H and speak, then release to paste."
echo "   Or tap SUPER + H once to start, and tap again to finish."
echo "3. Press SUPER + ESC to cancel anytime."
