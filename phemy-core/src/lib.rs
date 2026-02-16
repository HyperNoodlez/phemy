pub mod audio;
pub mod clipboard;
pub mod db;
pub mod ffi;
pub mod llm;
pub mod settings;
pub mod transcription;
pub mod utils;

use std::ffi::CString;
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::OnceLock;

use ffi::{c_str_to_str, str_to_c_char, to_json_c_char};

/// Tokio runtime for async operations
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

/// Guard against double-initialization
static INIT: OnceLock<bool> = OnceLock::new();

fn runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Runtime::new().expect("Failed to create tokio runtime")
    })
}

// ============================================================
// Init
// ============================================================

/// Initialize phemy-core with a data directory path.
/// Must be called before any other function.
/// Returns true on success, true (no-op) on subsequent calls.
#[no_mangle]
pub extern "C" fn phemy_init(data_dir: *const c_char) -> bool {
    let _ = env_logger::try_init();

    // Prevent double-initialization
    if INIT.get().is_some() {
        log::debug!("phemy_init called again — already initialized, skipping");
        return true;
    }

    let dir = match unsafe { c_str_to_str(data_dir) } {
        Some(s) => PathBuf::from(s),
        None => {
            dirs::data_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("phemy")
        }
    };

    settings::set_data_dir(dir.clone());

    let db_path = dir.join("phemy.db");
    match db::init(&db_path) {
        Ok(_) => {
            let _ = INIT.set(true);
            true
        }
        Err(e) => {
            log::error!("Failed to initialize database: {}", e);
            false
        }
    }
}

// ============================================================
// Settings
// ============================================================

/// Get current settings as JSON string.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_get_settings() -> *mut c_char {
    let settings = settings::Settings::load();
    to_json_c_char(&settings)
}

/// Save settings from a JSON string. Returns true on success.
#[no_mangle]
pub extern "C" fn phemy_save_settings(json: *const c_char) -> bool {
    let json_str = match unsafe { c_str_to_str(json) } {
        Some(s) => s,
        None => return false,
    };

    let settings: settings::Settings = match serde_json::from_str(json_str) {
        Ok(s) => s,
        Err(e) => {
            log::error!("Failed to parse settings JSON: {}", e);
            return false;
        }
    };

    match settings.save() {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to save settings: {}", e);
            false
        }
    }
}

/// Reset settings to defaults and return new settings as JSON.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_reset_settings() -> *mut c_char {
    let settings = settings::Settings::default();
    let _ = settings.save();
    to_json_c_char(&settings)
}

// ============================================================
// Audio
// ============================================================

/// List audio input devices as JSON array.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_list_audio_devices() -> *mut c_char {
    match audio::device::list_input_devices() {
        Ok(devices) => to_json_c_char(&devices),
        Err(e) => {
            log::error!("Failed to list audio devices: {}", e);
            str_to_c_char("[]")
        }
    }
}

/// Start recording. `device` may be null for default device.
/// `mic_cb` is a C function pointer called on the audio thread with (rms, peak), or null.
#[no_mangle]
pub extern "C" fn phemy_start_recording(
    device: *const c_char,
    mic_cb: Option<extern "C" fn(f32, f32)>,
) -> bool {
    let device_name = unsafe { c_str_to_str(device) };
    match audio::capture::start_recording(device_name, mic_cb) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to start recording: {}", e);
            false
        }
    }
}

/// Stop recording and return JSON with samples info.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_stop_recording() -> *mut c_char {
    match audio::capture::stop_recording() {
        Ok((samples, rate)) => {
            #[derive(serde::Serialize)]
            struct StopResult {
                sample_count: usize,
                sample_rate: u32,
                duration_secs: f64,
            }
            let result = StopResult {
                sample_count: samples.len(),
                sample_rate: rate,
                duration_secs: samples.len() as f64 / rate as f64,
            };
            to_json_c_char(&result)
        }
        Err(e) => {
            log::error!("Failed to stop recording: {}", e);
            std::ptr::null_mut()
        }
    }
}

/// Stop recording, transcribe, optimize, save to history, and return JSON result.
/// Always returns JSON (never null). On success: { "raw_transcript": "...", "optimized_prompt": "...", "mode": "...", "duration_secs": ... }
/// On error: { "error": "description of what went wrong" }
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_stop_and_process() -> *mut c_char {
    match stop_and_process_inner() {
        Ok(json) => json,
        Err(e) => {
            log::error!("stop_and_process failed: {}", e);
            #[derive(serde::Serialize)]
            struct ErrorResult { error: String }
            to_json_c_char(&ErrorResult { error: format!("{}", e) })
        }
    }
}

fn stop_and_process_inner() -> anyhow::Result<*mut c_char> {
    // 1. Stop recording → get samples
    let (samples, sample_rate) = audio::capture::stop_recording()?;

    if samples.is_empty() {
        anyhow::bail!("No audio samples captured");
    }

    let duration_secs = samples.len() as f64 / sample_rate as f64;
    let settings = settings::Settings::load();

    // 2. Transcribe
    let transcript = match runtime()
        .block_on(transcription::engine::transcribe(&samples, sample_rate, &settings))
    {
        Ok(result) => result.text,
        Err(e) => return Err(e),
    };

    if transcript.trim().is_empty() {
        anyhow::bail!("No speech detected in recording");
    }

    // 3. Optimize (unless raw mode)
    let opt_result = match runtime().block_on(llm::prompt_optimizer::optimize(&transcript, &settings)) {
        Ok(result) => result,
        Err(e) => {
            log::warn!("Optimization failed, using raw transcript: {}", e);
            llm::prompt_optimizer::OptimizationResult {
                raw_transcript: transcript.clone(),
                optimized_prompt: transcript.clone(),
                mode: format!("{:?}", settings.prompt_mode).to_lowercase(),
                provider: None,
            }
        }
    };

    // 4. Save to history
    let entry = db::new_history_entry(
        opt_result.raw_transcript.clone(),
        Some(opt_result.optimized_prompt.clone()),
        opt_result.mode.clone(),
        opt_result.provider.clone(),
        duration_secs,
    );
    if let Err(e) = db::insert_history(&entry) {
        log::error!("Failed to save history: {}", e);
    }

    // 5. Return JSON result
    #[derive(serde::Serialize)]
    struct ProcessResult {
        raw_transcript: String,
        optimized_prompt: String,
        mode: String,
        duration_secs: f64,
        #[serde(skip_serializing_if = "Option::is_none")]
        llm_error: Option<String>,
    }

    // Detect if optimization was skipped (raw == optimized and mode isn't "raw")
    let llm_error = if opt_result.raw_transcript == opt_result.optimized_prompt
        && opt_result.mode.to_lowercase() != "raw"
    {
        opt_result.provider.as_ref().and_then(|p| {
            if p.contains("failed") {
                Some(p.clone())
            } else {
                None
            }
        })
    } else {
        None
    };

    Ok(to_json_c_char(&ProcessResult {
        raw_transcript: opt_result.raw_transcript,
        optimized_prompt: opt_result.optimized_prompt,
        mode: opt_result.mode,
        duration_secs,
        llm_error,
    }))
}

/// Check if currently recording.
#[no_mangle]
pub extern "C" fn phemy_get_recording_state() -> bool {
    audio::capture::is_recording()
}

// ============================================================
// Transcription
// ============================================================

/// Transcribe audio samples. Returns JSON result.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_transcribe(
    samples: *const f32,
    len: usize,
    rate: u32,
) -> *mut c_char {
    if samples.is_null() || len == 0 {
        return std::ptr::null_mut();
    }

    let samples = unsafe { std::slice::from_raw_parts(samples, len) };
    let settings = settings::Settings::load();

    match runtime().block_on(transcription::engine::transcribe(samples, rate, &settings)) {
        Ok(result) => to_json_c_char(&result),
        Err(e) => {
            log::error!("Transcription failed: {}", e);
            std::ptr::null_mut()
        }
    }
}

/// List available whisper models as JSON array.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_list_whisper_models() -> *mut c_char {
    match transcription::model_manager::list_models() {
        Ok(models) => to_json_c_char(&models),
        Err(e) => {
            log::error!("Failed to list whisper models: {}", e);
            str_to_c_char("[]")
        }
    }
}

/// Download a whisper model by name. Blocking.
#[no_mangle]
pub extern "C" fn phemy_download_whisper_model(name: *const c_char) -> bool {
    let name = match unsafe { c_str_to_str(name) } {
        Some(s) => s,
        None => return false,
    };

    match runtime().block_on(transcription::model_manager::download_model(name)) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to download model: {}", e);
            false
        }
    }
}

/// Get download progress as JSON, or null if not downloading.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_get_download_progress() -> *mut c_char {
    match transcription::model_manager::get_download_progress() {
        Some(progress) => to_json_c_char(&progress),
        None => std::ptr::null_mut(),
    }
}

// ============================================================
// LLM
// ============================================================

/// Optimize a transcript into a polished prompt. Returns JSON.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_optimize_prompt(transcript: *const c_char) -> *mut c_char {
    let transcript = match unsafe { c_str_to_str(transcript) } {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };

    let settings = settings::Settings::load();
    match runtime().block_on(llm::prompt_optimizer::optimize(transcript, &settings)) {
        Ok(result) => to_json_c_char(&result),
        Err(e) => {
            log::error!("Optimization failed: {}", e);
            std::ptr::null_mut()
        }
    }
}

/// List available local LLM models as JSON array.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_list_llm_models() -> *mut c_char {
    match llm::llm_model_manager::list_models() {
        Ok(models) => to_json_c_char(&models),
        Err(e) => {
            log::error!("Failed to list LLM models: {}", e);
            str_to_c_char("[]")
        }
    }
}

/// Download a local LLM model by name. Blocking.
#[no_mangle]
pub extern "C" fn phemy_download_llm_model(name: *const c_char) -> bool {
    let name = match unsafe { c_str_to_str(name) } {
        Some(s) => s,
        None => return false,
    };

    match runtime().block_on(llm::llm_model_manager::download_model(name)) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to download LLM model: {}", e);
            false
        }
    }
}

/// Get LLM model download progress as JSON, or null if not downloading.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_get_llm_download_progress() -> *mut c_char {
    match llm::llm_model_manager::get_download_progress() {
        Some(progress) => to_json_c_char(&progress),
        None => std::ptr::null_mut(),
    }
}

/// Delete a downloaded whisper model by name. Returns true on success.
#[no_mangle]
pub extern "C" fn phemy_delete_whisper_model(name: *const c_char) -> bool {
    let name = match unsafe { c_str_to_str(name) } {
        Some(s) => s,
        None => return false,
    };

    match transcription::model_manager::delete_model(name) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to delete whisper model: {}", e);
            false
        }
    }
}

/// Delete a downloaded LLM model by name. Returns true on success.
#[no_mangle]
pub extern "C" fn phemy_delete_llm_model(name: *const c_char) -> bool {
    let name = match unsafe { c_str_to_str(name) } {
        Some(s) => s,
        None => return false,
    };

    match llm::llm_model_manager::delete_model(name) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to delete LLM model: {}", e);
            false
        }
    }
}

// ============================================================
// History
// ============================================================

/// Get history entries as JSON array.
/// Caller must free the returned string with phemy_free_string().
#[no_mangle]
pub extern "C" fn phemy_get_history(limit: i32, offset: i32) -> *mut c_char {
    match db::get_history(limit as usize, offset as usize) {
        Ok(entries) => to_json_c_char(&entries),
        Err(e) => {
            log::error!("Failed to get history: {}", e);
            str_to_c_char("[]")
        }
    }
}

/// Delete a history entry by ID. Returns true on success.
#[no_mangle]
pub extern "C" fn phemy_delete_history_entry(id: *const c_char) -> bool {
    let id = match unsafe { c_str_to_str(id) } {
        Some(s) => s,
        None => return false,
    };

    match db::delete_history_entry(id) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to delete history entry: {}", e);
            false
        }
    }
}

/// Clear all history. Returns true on success.
#[no_mangle]
pub extern "C" fn phemy_clear_history() -> bool {
    match db::clear_history() {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to clear history: {}", e);
            false
        }
    }
}

// ============================================================
// Clipboard
// ============================================================

/// Paste text into the focused application.
#[no_mangle]
pub extern "C" fn phemy_paste_text(text: *const c_char) -> bool {
    let text = match unsafe { c_str_to_str(text) } {
        Some(s) => s,
        None => return false,
    };

    let settings = settings::Settings::load();
    match clipboard::paste::paste_via_clipboard(
        text,
        &settings.paste_method,
        settings.paste_delay_ms,
    ) {
        Ok(_) => true,
        Err(e) => {
            log::error!("Failed to paste text: {}", e);
            false
        }
    }
}

// ============================================================
// Memory management
// ============================================================

/// Free a string returned by any phemy_* function.
#[no_mangle]
pub extern "C" fn phemy_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
