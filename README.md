<p align="center">
  <img src="visual%20assets/App_Logo.png" alt="Kord" width="180" />
</p>

<h1 align="center">Kord</h1>

<p align="center">
  <strong>Speak naturally. Get a polished prompt. Paste it anywhere.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/SwiftUI-5.10-orange?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Rust-1.75%2B-orange?logo=rust&logoColor=white" alt="Rust" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  <img src="https://img.shields.io/badge/100%25-offline-blueviolet" alt="Offline" />
</p>

---

Kord is a **completely offline** macOS menu bar app that turns your voice into polished, LLM-optimized prompts. Press a hotkey, speak your thoughts, and Kord transcribes with local Whisper, refines with a local LLM, and pastes the result directly into whatever app you're using — no cloud, no API keys, no data leaves your machine.

---

## How It Works

```
  Alt+Space          Local Whisper           Local LLM            Auto-Paste
 ┌──────────┐      ┌──────────────┐      ┌──────────────┐      ┌───────────┐
 │  Speak   │ ──▶  │  Transcribe  │ ──▶  │   Optimize   │ ──▶  │   Paste   │
 │  freely  │      │  on-device   │      │   on-device  │      │  anywhere │
 └──────────┘      └──────────────┘      └──────────────┘      └───────────┘
```

1. **Press the hotkey** (default: `Alt+Space`) — a floating overlay appears
2. **Speak naturally** — watch the audio-reactive ring respond to your voice
3. **Release or press again** — Kord transcribes and optimizes your speech
4. **Press Enter** — the polished prompt is pasted into the focused app

The entire pipeline runs on-device. Your voice data never leaves your Mac.

---

## Getting Started

### Prerequisites

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install cmake
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # restart Terminal after
cargo install cbindgen
```

### Build & Run

```bash
git clone https://github.com/HyperNoodlez/kord-for-macos.git
cd kord-for-macos
./build-rust.sh    # first build takes several minutes
swift run
```

### First Launch

1. Click the menu bar icon → **Show Settings**
2. **Transcription** → download `base` (142 MB)
3. **LLM** → download `Qwen2.5 1.5B` (1 GB, fastest) or `Qwen3 4B` (2.7 GB, best quality)
4. Press **`Alt+Space`**, speak, press **Enter** to paste

---

## Features

### Completely Offline
Every component runs locally. Whisper handles transcription. A quantized Qwen LLM handles prompt optimization. No internet connection required after initial model downloads.

### Global Hotkey with Recording Overlay
Trigger Kord from any app with a system-wide keyboard shortcut. The transparent floating overlay shows real-time audio visualization without stealing focus from your current window.

- **Toggle mode** — press once to start, press again to stop
- **Push-to-talk** — hold to record, release to stop
- Customizable hotkey (any modifier + key combination)

### 8 Prompt Modes

| Mode | Description |
|------|-------------|
| **Clean** | Remove filler words, fix grammar, preserve intent |
| **Technical** | Precise technical terminology, clear requirements |
| **Formal** | Professional language, business-appropriate tone |
| **Casual** | Clean but conversational, friendly voice |
| **Code** | Structured coding task with language and requirements |
| **Verbatim** | Minimal cleanup, closest to original wording |
| **Raw** | No LLM processing — direct transcript output |
| **Custom** | Use your own system prompt |

### Flexible Paste Methods
Four ways to deliver text to your target app:

- **Cmd+V** — standard paste (default)
- **Cmd+Shift+V** — plain text paste (strips formatting)
- **Shift+Insert** — alternative paste
- **Type Out** — simulates keystrokes character-by-character

Configurable delay (0–500ms) lets focus return to the target app before pasting.

### Accent Themes
Six color themes that tint the entire UI — buttons, badges, the recording ring, and mode cards:

`Purple` · `Blue` · `Teal` · `Rose` · `Orange` · `Emerald`

### History
Every recording is saved to a local SQLite database with the raw transcript, optimized prompt, mode used, and duration. Browse, search, and delete entries from the History tab.

---

## Models

### Whisper (Transcription)

Downloaded from [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) on first use.

| Model | Size | Speed | Notes |
|-------|------|-------|-------|
| tiny | 75 MB | Fastest | Quick tests |
| **base** | **142 MB** | **Fast** | **Recommended** |
| small | 466 MB | Medium | Better accuracy |
| medium | 1.5 GB | Slow | High accuracy |
| large-v3 | 3.1 GB | Slowest | Maximum accuracy |

### LLM (Prompt Optimization)

All models are Q4_K_M quantized GGUF files from the [Qwen](https://huggingface.co/Qwen) family, running via llama.cpp with Metal GPU acceleration.

| Model | Size | Notes |
|-------|------|-------|
| **Qwen3 4B Instruct** | **2.7 GB** | **Best quality** |
| Qwen2.5 3B Instruct | 2.0 GB | Great balance of speed and quality |
| Qwen2.5 1.5B Instruct | 1.0 GB | Smallest and fastest |

Expect ~30–50 tokens/sec on Apple Silicon. Prompt optimization typically completes in under 2 seconds.


---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <img src="visual%20assets/Company_logo.png" alt="Lab.gargé" width="140" />
</p>

<p align="center">
  <sub>Built by <strong>Lab.gargé</strong></sub>
</p>
