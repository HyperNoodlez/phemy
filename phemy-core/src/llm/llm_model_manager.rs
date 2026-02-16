use anyhow::Result;
use serde::Serialize;
use sha2::{Digest, Sha256};
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

/// (display_name, gguf_filename, size_mb, description, download_url, sha256_hex)
///
/// NOTE: Only models WITHOUT tied embeddings work with llama-cpp-2 v0.1.x.
/// Models with tied embeddings (Llama 3.2, SmolLM2, Gemma-2, Phi-4) cause
/// "tensor 'token_embd.weight' is duplicated" errors.
/// Qwen models use a large vocab (151K) so they never tie embeddings.
const MODELS: &[(&str, &str, u64, &str, &str, &str)] = &[
    (
        "qwen3-4b-instruct-q4km",
        "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
        2700,
        "Qwen3 4B — best quality for prompt optimization",
        "https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
        "3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597",
    ),
    (
        "qwen2.5-3b-instruct-q4km",
        "qwen2.5-3b-instruct-q4_k_m.gguf",
        2020,
        "Qwen2.5 3B — great balance of speed and quality",
        "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
        "626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d",
    ),
    (
        "qwen2.5-1.5b-instruct-q4km",
        "qwen2.5-1.5b-instruct-q4_k_m.gguf",
        1010,
        "Qwen2.5 1.5B — smallest and fastest, minimal resource usage",
        "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e",
    ),
];

fn llm_models_dir() -> Result<PathBuf> {
    let base = crate::settings::get_data_dir().unwrap_or_else(|| {
        dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("phemy")
    });
    let dir = base.join("models").join("llm");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn get_model_path(name: &str) -> Result<PathBuf> {
    let models_dir = llm_models_dir()?;
    let filename = MODELS
        .iter()
        .find(|(n, _, _, _, _, _)| *n == name)
        .map(|(_, f, _, _, _, _)| *f)
        .ok_or_else(|| anyhow::anyhow!("Unknown LLM model: {}", name))?;

    anyhow::ensure!(
        !filename.contains("..") && !filename.contains('/'),
        "Invalid model filename: {}",
        filename
    );

    Ok(models_dir.join(filename))
}

pub fn list_models() -> Result<Vec<LlmModelInfo>> {
    let models_dir = llm_models_dir()?;

    Ok(MODELS
        .iter()
        .map(|(name, filename, size_mb, description, _, _sha256)| {
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
    let (_, filename, _, _, url, expected_sha256) = MODELS
        .iter()
        .find(|(n, _, _, _, _, _)| *n == name)
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
    let mut hasher = Sha256::new();

    let mut file = tokio::fs::File::create(&dest).await?;
    let mut stream = response.bytes_stream();

    use futures_util::StreamExt;
    use tokio::io::AsyncWriteExt;

    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        file.write_all(&chunk).await?;
        hasher.update(&chunk);
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

    // Verify SHA256 checksum
    let actual_sha256 = format!("{:x}", hasher.finalize());
    if actual_sha256 != *expected_sha256 {
        // Remove the corrupted file
        let _ = tokio::fs::remove_file(&dest).await;
        anyhow::bail!(
            "SHA256 mismatch for model '{}': expected {}, got {}",
            name,
            expected_sha256,
            actual_sha256
        );
    }

    log::info!("LLM model '{}' downloaded and verified (SHA256 OK) at {:?}", name, dest);
    Ok(())
}

pub fn get_download_progress() -> Option<LlmDownloadProgress> {
    DOWNLOAD_PROGRESS.lock().ok()?.clone()
}

/// Delete a downloaded LLM model by name. Unloads first if currently loaded.
pub fn delete_model(name: &str) -> Result<()> {
    let path = get_model_path(name)?;
    // Unload the model if it's currently loaded
    if super::local::is_loaded() {
        super::local::unload();
    }
    match std::fs::remove_file(&path) {
        Ok(_) => {
            log::info!("Deleted LLM model '{}' at {:?}", name, path);
            Ok(())
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            anyhow::bail!("Model '{}' is not downloaded", name)
        }
        Err(e) => Err(e.into()),
    }
}
