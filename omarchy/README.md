# Whisper Dictation for Omarchy Linux

An Omarchy Shell Plugin and native dictation system for Arch Linux + Hyprland. Powered by Groq's accuracy-focused `whisper-large-v3` for Thai/English transcription, with optional `openai/gpt-oss-120b` grammar and punctuation correction.

## Features

- 🎙️ **Dual-Mode Hotkey (`SUPER + H`)**:
  - **Hold-to-Talk**: Hold `SUPER + H`, speak, and release to paste immediately.
  - **Tap-to-Toggle**: Tap `SUPER + H` once to start speaking, tap again to finish.
- ❌ **Instant Cancel (`SUPER + ESC`)**: Abort active dictation without sending audio to the cloud.
- ⚡ **Groq 2-Stage Pipeline**:
  - Stage 1: `whisper-large-v3` Speech-to-Text.
  - Optional Stage 2: `openai/gpt-oss-120b` punctuation, spacing, and context-aware English term correction. Enable `correct_text` to handle terms beyond the built-in names.
  - Common product names spoken in Thai (such as ดิสคอร์ด → Discord and แชตจีพีที → ChatGPT) are restored to English spelling before pasting.
- 📋 **Smart Wayland Auto-Paste**:
  - Automatically detects whether the focused window is a Terminal (`foot`, `alacritty`, `kitty`, `ghostty`) or a GUI app (`Ctrl+Shift+V` vs `Ctrl+V`).
  - Preserves and restores existing clipboard content after pasting.
- 🌊 **Bottom-Center Floating OSD**:
  - Quickshell overlay with voice-reactive level bars while recording, elapsed timer, transcribing/polishing spinner, and completion checkmark.
- 📊 **Omarchy Bar Widget (`yux.whisper`)**:
  - Displays mic status in the top bar.
  - Popup panel allows configuring Groq API key, toggling AI correction, and viewing recent dictation history with click-to-copy.

## Quick Installation

Run the automated installer from the repository root:

```bash
cd /home/yux/Projects/WhisperApp/omarchy
./install.sh
```

The script will:
1. Symlink the plugin to `~/.config/omarchy/plugins/yux.whisper`
2. Symlink the `whisper-ctl` command to `~/.local/bin/whisper-ctl`
3. Add `yux.whisper` to your Omarchy bar in `~/.config/omarchy/shell.json`
4. Register the `SUPER + H` and `SUPER + ESC` shortcuts in `~/.config/hypr/bindings.lua`
5. Reload Hyprland and Omarchy Shell

## Configuration

Set your Groq API key via CLI:

```bash
whisper-ctl set-key gsk_your_api_key_here
```

Or simply click the mic icon on the Omarchy top bar, enter your key in the Settings card, and click **Save Key**.

You can also use the `GROQ_API_KEY` environment variable in your shell profile.

## CLI Usage

```bash
# Start/stop dictation
whisper-ctl toggle

# View current state
whisper-ctl status

# View recent dictations
whisper-ctl history

# Open Omarchy bar popup panel
whisper-ctl open

# Configure settings
whisper-ctl config set correct_text false
```

The built-in English spelling list handles clear product names even with AI correction off. To let AI decide whether a Thai phonetic spelling represents an English technical term, enable correction in the panel or run `whisper-ctl config set correct_text true`. The AI prompt asks it to leave ambiguous everyday words in Thai. Your `custom_dictionary` rules apply last and can override the built-in spelling.
