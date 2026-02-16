use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Mutex;

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum PromptMode {
    Clean,
    Technical,
    Formal,
    Casual,
    Code,
    Verbatim,
    Raw,
    Custom,
}

impl Default for PromptMode {
    fn default() -> Self {
        Self::Clean
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum PasteMethod {
    CtrlV,
    CtrlShiftV,
    ShiftInsert,
    TypeOut,
}

impl Default for PasteMethod {
    fn default() -> Self {
        Self::CtrlV
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum HotkeyMode {
    Toggle,
    PushToTalk,
}

impl Default for HotkeyMode {
    fn default() -> Self {
        Self::Toggle
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum Theme {
    System,
    Light,
    Dark,
}

impl Default for Theme {
    fn default() -> Self {
        Self::System
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    // Audio
    pub input_device: Option<String>,

    // Transcription
    pub whisper_model: String,
    pub language: String,

    // LLM
    pub prompt_mode: PromptMode,
    pub custom_system_prompt: Option<String>,
    pub local_llm_model: Option<String>,

    // Paste
    pub paste_method: PasteMethod,
    pub paste_delay_ms: u64,
    pub auto_submit: bool,

    // Hotkey
    pub hotkey: String,
    pub hotkey_mode: HotkeyMode,

    // General
    pub theme: Theme,
    pub launch_at_startup: bool,

    // Vocabulary
    pub vocabulary: Vec<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            input_device: None,
            whisper_model: "base".to_string(),
            language: "en".to_string(),
            prompt_mode: PromptMode::default(),
            custom_system_prompt: None,
            local_llm_model: Some("qwen3-4b-instruct-q4km".to_string()),
            paste_method: PasteMethod::default(),
            paste_delay_ms: 100,
            auto_submit: false,
            hotkey: "Alt+Space".to_string(),
            hotkey_mode: HotkeyMode::default(),
            theme: Theme::default(),
            launch_at_startup: false,
            vocabulary: Vec::new(),
        }
    }
}

/// Global data directory set during kord_init
static DATA_DIR: std::sync::LazyLock<Mutex<Option<PathBuf>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

/// Set the data directory (called from kord_init)
pub fn set_data_dir(path: PathBuf) {
    if let Ok(mut dir) = DATA_DIR.lock() {
        *dir = Some(path);
    }
}

/// Get the data directory set by kord_init, if any.
pub fn get_data_dir() -> Option<PathBuf> {
    DATA_DIR.lock().ok()?.clone()
}

/// Get the settings file path
fn settings_path() -> anyhow::Result<PathBuf> {
    let dir = DATA_DIR
        .lock()
        .map_err(|e| anyhow::anyhow!("{}", e))?
        .clone()
        .unwrap_or_else(|| {
            dirs::data_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("kord")
        });

    std::fs::create_dir_all(&dir)?;
    Ok(dir.join("settings.json"))
}

impl Settings {
    /// Load settings from JSON file on disk
    pub fn load() -> Self {
        let path = match settings_path() {
            Ok(p) => p,
            Err(_) => return Self::default(),
        };

        if !path.exists() {
            return Self::default();
        }

        match std::fs::read_to_string(&path) {
            Ok(contents) => serde_json::from_str(&contents).unwrap_or_default(),
            Err(_) => Self::default(),
        }
    }

    /// Save settings to JSON file on disk
    pub fn save(&self) -> anyhow::Result<()> {
        let path = settings_path()?;
        let json = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, &json)?;

        // Set restrictive permissions (owner-only read/write)
        #[cfg(unix)]
        {
            let perms = std::fs::Permissions::from_mode(0o600);
            if let Err(e) = std::fs::set_permissions(&path, perms) {
                log::warn!("Failed to set settings file permissions: {}", e);
            }
        }

        Ok(())
    }
}
