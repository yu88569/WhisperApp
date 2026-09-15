# Whisper (Omarchy Port)

Voice-to-text dictation system for Omarchy Linux (Hyprland + Quickshell) featuring dual-mode triggering, real-time status overlay, Groq-accelerated transcription, and context-aware LLM text correction.

## Language

**Dictation Session**:
A single end-to-end lifecycle of voice-to-text input, from trigger activation through audio capture, transcription, LLM correction, to active window text injection.
_Avoid_: Recording session, voice note, speech run

**Dictation Controller**:
The central state machine managing session states (`idle`, `recording`, `transcribing`, `correcting`, `pasting`, `done`, `error`).
_Avoid_: Manager, coordinator, supervisor

**Audio Capture Engine**:
The PipeWire recorder streaming microphone input into 16 kHz mono 16-bit PCM WAV audio.
_Avoid_: Sound listener, mic recorder, voice input

**STT Service**:
The Speech-to-Text client calling Groq's `whisper-large-v3-turbo` model to produce raw transcribed text.
_Avoid_: Transcriber, speech decoder

**Text Correction Service**:
The LLM client calling Groq's `llama-3.3-70b-versatile` model to fix homophones, typos, casing, punctuation, and Thai/English terminology without altering meaning.
_Avoid_: Polisher, rewriter, summarizer

**Text Injector**:
The Wayland text insertion component that places text into the system clipboard via `wl-copy` and triggers simulated paste via `wtype` into the focused Hyprland window, then restores previous clipboard content.
_Avoid_: Auto-typer, virtual keyboard sender, paster

**Status OSD**:
A floating Wayland layer-shell overlay rendered by Quickshell that displays the active dictation state, audio waveform, and feedback pill.
_Avoid_: HUD, popup toast, modal window

**Omarchy Bar Plugin**:
The Quickshell widget in the Omarchy top bar (`yux.whisper`) exposing toggle actions, mic status, and a settings/history dropdown panel.
_Avoid_: System tray icon, dock applet
