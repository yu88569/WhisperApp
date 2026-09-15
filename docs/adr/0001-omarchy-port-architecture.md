# Omarchy Port Architecture and Dual-Mode Dictation

We ported Whisper to Omarchy Linux as an Omarchy Shell Plugin (`yux.whisper`) paired with a Python 3 CLI daemon (`whisper-ctl`), triggered via Hyprland's `bind` and `bindr` on `SUPER + H`. This preserves WhisperApp's signature 2-stage Groq pipeline (Groq Whisper STT + Groq Llama 3.3 text correction) and dual-mode push-to-talk/toggle behavior natively on Wayland without requiring root evdev permissions or third-party daemon runtimes.

## Considered Options

- **Voxtype wrapper**: Rejected because Voxtype does not support custom 2-stage LLM grammar/bilingual correction prompts or Omarchy Quickshell UI widgets.
- **Standalone Wayland GTK/Layer-Shell app**: Rejected because building a native Omarchy Shell Plugin integrates seamlessly with the existing status bar, theme system, and Quickshell OSD on this machine.
- **Evdev hotkey listener daemon**: Rejected because reading `/dev/input/` requires membership in the input group or root privileges, whereas Hyprland's native `bind`/`bindr` handles modifier combinations cleanly in user space.
