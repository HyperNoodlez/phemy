<p align="center">
  <img src="visual%20assets/App_Logo.png" alt="Phemy — free open-source AI voice dictation for macOS" width="180" />
</p>

<h1 align="center">Phemy</h1>

<p align="center">
  <strong>Free, open-source, fully local AI voice dictation for macOS. The offline alternative to Wispr Flow, Willow, and Aqua Voice.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/SwiftUI-5.10-orange?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Rust-1.75%2B-orange?logo=rust&logoColor=white" alt="Rust" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  <img src="https://img.shields.io/badge/100%25-offline-blueviolet" alt="Offline" />
  <img src="https://img.shields.io/badge/cost-%240%2Fmo-brightgreen" alt="Free forever" />
</p>

---

Phemy is a **completely offline** macOS menu bar app that turns your voice into polished, LLM-optimized text. Press a hotkey, speak your thoughts, and Phemy transcribes with local Whisper, refines with a local LLM, and pastes the result directly into whatever app you're using — no cloud, no API keys, no subscription, no data leaves your machine.

**Think of it as Wispr Flow or Willow, but free, open-source, and fully private.** No usage limits. No word caps. No account required. Everything runs on your Mac.

---

## Why Phemy?

Most AI dictation tools charge $8–15/month and send your voice to the cloud. Phemy does the same thing for free, forever, with zero network requests.

| | Phemy | Wispr Flow | Willow | Aqua Voice | SuperWhisper |
|---|:---:|:---:|:---:|:---:|:---:|
| **Price** | **Free** | $12/mo | $12/mo | $8/mo | $5/mo |
| **Open source** | **Yes** | No | No | No | No |
| **Fully offline** | **Yes** | No | No | No | Partial |
| **Voice → LLM prompt** | **Yes** | Yes | Yes | Yes | No |
| **Auto-paste** | **Yes** | Yes | Yes | Yes | Yes |
| **No account required** | **Yes** | No | No | No | No |
| **Your data stays local** | **Yes** | No | No | No | Partial |

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
3. **Release or press again** — Phemy transcribes and optimizes your speech
4. **Press Enter** — the polished text is pasted into the focused app

The entire pipeline runs on-device. Your voice data never leaves your Mac.

---

## Getting Started

### Install (recommended)

1. Download `Phemy.dmg` from the [latest release](https://github.com/HyperNoodlez/phemy/releases/latest)
2. Open the DMG and drag `Phemy.app` to `/Applications`
3. Launch Phemy from your Applications folder
4. macOS may show "app from an unidentified developer" — right-click → **Open** to bypass

> Requires macOS 14+ on Apple Silicon.

### Build from Source

#### Prerequisites

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install cmake
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # restart Terminal after
cargo install cbindgen
```

#### Build & Run

```bash
git clone https://github.com/HyperNoodlez/phemy.git
cd phemy
./build-rust.sh    # first build takes several minutes
swift run
```

#### First Launch

1. Click the menu bar icon → **Show Settings**
2. **Transcription** → download `base` (142 MB)
3. **LLM** → download `Qwen2.5 1.5B` (1 GB, fastest) or `Qwen3 4B` (2.7 GB, best quality)
4. Press **`Alt+Space`**, speak, press **Enter** to paste

---

## Features

### Completely Offline
Every component runs locally — Whisper for speech-to-text, a quantized Qwen LLM for text refinement. No internet connection required after model downloads. No telemetry. No analytics.

### Global Hotkey with Recording Overlay
Trigger Phemy from any app with a system-wide keyboard shortcut. The transparent floating overlay shows real-time audio visualization without stealing focus from your current window.

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

- **Cmd+V** — standard paste (default)
- **Cmd+Shift+V** — plain text paste (strips formatting)
- **Shift+Insert** — alternative paste
- **Type Out** — simulates keystrokes character-by-character

Configurable delay (0–500ms) lets focus return to the target app before pasting.

### Accent Themes
Six color themes that tint the entire UI — buttons, badges, the recording ring, and mode cards:

`Purple` · `Blue` · `Teal` · `Rose` · `Orange` · `Emerald`

### History
Every recording is saved locally with the raw transcript, optimized text, mode used, and duration. Browse and delete entries from the History tab.

---

## Models

### Whisper (Speech-to-Text)

Downloaded from [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) on first use.

| Model | Size | Speed | Notes |
|-------|------|-------|-------|
| tiny | 75 MB | Fastest | Quick tests |
| **base** | **142 MB** | **Fast** | **Recommended** |
| small | 466 MB | Medium | Better accuracy |
| medium | 1.5 GB | Slow | High accuracy |
| large-v3 | 3.1 GB | Slowest | Maximum accuracy |

### LLM (Text Optimization)

Q4_K_M quantized GGUF models from the [Qwen](https://huggingface.co/Qwen) family, running via llama.cpp with Metal GPU acceleration on Apple Silicon.

| Model | Size | Notes |
|-------|------|-------|
| **Qwen3 4B Instruct** | **2.7 GB** | **Best quality** |
| Qwen2.5 3B Instruct | 2.0 GB | Great balance of speed and quality |
| Qwen2.5 1.5B Instruct | 1.0 GB | Smallest and fastest |

~30–50 tokens/sec on Apple Silicon. Prompt optimization completes in under 2 seconds.

---

## FAQ

**How does this compare to macOS built-in Dictation?**
Built-in Dictation gives you a raw transcript. Phemy goes further — it cleans up filler words, fixes grammar, reformats for context (code, email, technical docs), and auto-pastes the result. It's voice-to-polished-text, not just voice-to-text.

**Does it work with ChatGPT, Cursor, Slack, etc.?**
Yes. Phemy pastes into whatever app has focus. It works everywhere you can type — ChatGPT, Cursor, VS Code, Slack, Gmail, Notion, Terminal, or any other app.

**How accurate is the transcription?**
Phemy uses OpenAI's Whisper models running locally. The `base` model is fast and accurate for everyday use. The `large-v3` model matches state-of-the-art cloud transcription accuracy.

**Does it work without internet?**
Yes, 100%. After you download the models (one-time), Phemy never makes a network request. Airplane mode, no Wi-Fi, air-gapped — it all works.

**What languages are supported?**
Whisper supports 99 languages. Set the language code in Transcription settings (e.g., `en`, `es`, `fr`, `de`, `ja`, `zh`).

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <img src="visual%20assets/Logo_white.png" alt="Lab.gargé" width="140" />
</p>

<p align="center">
  <sub>Built by <strong>Lab.gargé</strong></sub>
</p>
