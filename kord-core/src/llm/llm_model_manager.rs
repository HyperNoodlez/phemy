use anyhow::Result;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize)]
pub struct LlmModelInfo {
    pub name: String,
    pub size_mb: u64,
    pub downloaded: bool,
    pub description: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmDownloadProgress {
    pub model: String,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub progress: f64,
}

static DOWNLOAD_PROGRESS: std::sync::LazyLock<Mutex<Option<LlmDownloadProgress>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

/// (display_name, gguf_filename, size_mb, description, download_url)
///
/// NOTE: Only models WITHOUT tied embeddings work with llama-cpp-2 v0.1.x.
/// Models with tied embeddings (Llama 3.2, SmolLM2, Gemma-2, Phi-4) cause
/// "tensor 'token_embd.weight' is duplicated" errors.
/// Qwen models use a large vocab (151K) so they never tie embeddings.
const MODELS: &[(&str, &str, u64, &str, &str)] = &[
    (
        "qwen3-4b-instruct-q4km",
        "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
        2700,
        "Qwen3 4B — best quality for prompt optimization",
        "https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
    ),
    (
        "qwen2.5-3b-instruct-q4km",
        "qwen2.5-3b-instruct-q4_k_m.gguf",
        2020,
        "Qwen2.5 3B — great balance of speed and quality",
        "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
    ),
    (
        "qwen2.5-1.5b-instruct-q4km",
        "qwen2.5-1.5b-instruct-q4_k_m.gguf",
        1010,
        "Qwen2.5 1.5B — smallest and fastest, minimal resource usage",
        "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
    ),
];

fn llm_models_dir() -> Result<PathBuf> {
    let base = crate::settings::get_data_dir().unwrap_or_else(|| {
        dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("kord")
    });
    let dir = base.join("models").join("llm");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn get_model_path(name: &str) -> Result<PathBuf> {
    let models_dir = llm_models_dir()?;
    let filename = MODELS
        .iter()
        .find(|(n, _, _, _, _)| *n == name)
        .map(|(_, f, _, _, _)| *f)
        .ok_or_else(|| anyhow::anyhow!("Unknown LLM model: {}", name))?;

    Ok(models_dir.join(filename))
}

pub fn list_models() -> Result<Vec<LlmModelInfo>> {
    let models_dir = llm_models_dir()?;

    Ok(MODELS
        .iter()
        .map(|(name, filename, size_mb, description, _)| {
            let path = models_dir.join(filename);
            LlmModelInfo {
                name: name.to_string(),
                size_mb: *size_mb,
                downloaded: path.exists(),
                description: description.to_string(),
            }
        })
        .collect())
}

pub async fn download_model(name: &str) -> Result<()> {
    let (_, filename, _, _, url) = MODELS
        .iter()
        .find(|(n, _, _, _, _)| *n == name)
        .ok_or_else(|| anyhow::anyhow!("Unknown LLM model: {}", name))?;

    let dest = llm_models_dir()?.join(filename);

    log::info!("Downloading LLM model '{}' from {}", name, url);

    let client = reqwest::Client::new();
    let response = client.get(*url).send().await?;

    if !response.status().is_success() {
        anyhow::bail!("Failed to download LLM model: HTTP {}", response.status());
    }

    let total_bytes = response.content_length().unwrap_or(0);
    let mut downloaded_bytes: u64 = 0;

    let mut file = tokio::fs::File::create(&dest).await?;
    let mut stream = response.bytes_stream();

    use futures_util::StreamExt;
    use tokio::io::AsyncWriteExt;

    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        file.write_all(&chunk).await?;
        downloaded_bytes += chunk.len() as u64;

        let progress = if total_bytes > 0 {
            downloaded_bytes as f64 / total_bytes as f64
        } else {
            0.0
        };

        if let Ok(mut p) = DOWNLOAD_PROGRESS.lock() {
            *p = Some(LlmDownloadProgress {
                model: name.to_string(),
                downloaded_bytes,
                total_bytes,
                progress,
            });
        }
    }

    file.flush().await?;

    // Clear progress
    if let Ok(mut p) = DOWNLOAD_PROGRESS.lock() {
        *p = None;
    }

    log::info!("LLM model '{}' downloaded to {:?}", name, dest);
    Ok(())
}

pub fn get_download_progress() -> Option<LlmDownloadProgress> {
    DOWNLOAD_PROGRESS.lock().ok()?.clone()
}

/// Delete a downloaded LLM model by name. Unloads first if currently loaded.
pub fn delete_model(name: &str) -> Result<()> {
    let path = get_model_path(name)?;
    if path.exists() {
        // Unload the model if it's currently loaded
        if super::local::is_loaded() {
            super::local::unload();
        }
        std::fs::remove_file(&path)?;
        log::info!("Deleted LLM model '{}' at {:?}", name, path);
    } else {
        anyhow::bail!("Model '{}' is not downloaded", name);
    }
    Ok(())
}
