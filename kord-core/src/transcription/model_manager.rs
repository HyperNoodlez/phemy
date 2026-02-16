use anyhow::Result;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize)]
pub struct WhisperModel {
    pub name: String,
    pub size_mb: u64,
    pub downloaded: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct DownloadProgress {
    pub model: String,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub progress: f64,
}

static DOWNLOAD_PROGRESS: std::sync::LazyLock<Mutex<Option<DownloadProgress>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

const MODELS: &[(&str, &str, u64)] = &[
    ("tiny", "ggml-tiny.bin", 75),
    ("base", "ggml-base.bin", 142),
    ("small", "ggml-small.bin", 466),
    ("medium", "ggml-medium.bin", 1500),
    ("large-v3", "ggml-large-v3.bin", 3100),
];

const HF_BASE_URL: &str =
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

pub fn get_model_path(name: &str) -> Result<PathBuf> {
    let models_dir = crate::utils::models_dir()?;
    let filename = MODELS
        .iter()
        .find(|(n, _, _)| *n == name)
        .map(|(_, f, _)| *f)
        .ok_or_else(|| anyhow::anyhow!("Unknown whisper model: {}", name))?;

    Ok(models_dir.join(filename))
}

pub fn list_models() -> Result<Vec<WhisperModel>> {
    let models_dir = crate::utils::models_dir()?;

    Ok(MODELS
        .iter()
        .map(|(name, filename, size_mb)| {
            let path = models_dir.join(filename);
            WhisperModel {
                name: name.to_string(),
                size_mb: *size_mb,
                downloaded: path.exists(),
            }
        })
        .collect())
}

pub async fn download_model(name: &str) -> Result<()> {
    let (_, filename, _) = MODELS
        .iter()
        .find(|(n, _, _)| *n == name)
        .ok_or_else(|| anyhow::anyhow!("Unknown whisper model: {}", name))?;

    let url = format!("{}/{}", HF_BASE_URL, filename);
    let dest = crate::utils::models_dir()?.join(filename);

    log::info!("Downloading whisper model '{}' from {}", name, url);

    let client = reqwest::Client::new();
    let response = client.get(&url).send().await?;

    if !response.status().is_success() {
        anyhow::bail!("Failed to download model: HTTP {}", response.status());
    }

    let total_bytes = response.content_length().unwrap_or(0);
    let mut downloaded_bytes: u64 = 0;

    let mut file = tokio::fs::File::create(&dest).await?;
    let mut stream = response.bytes_stream();

    use tokio::io::AsyncWriteExt;
    use futures_util::StreamExt;

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
            *p = Some(DownloadProgress {
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

    log::info!("Model '{}' downloaded to {:?}", name, dest);
    Ok(())
}

pub fn get_download_progress() -> Option<DownloadProgress> {
    DOWNLOAD_PROGRESS.lock().ok()?.clone()
}

/// Delete a downloaded whisper model by name.
pub fn delete_model(name: &str) -> Result<()> {
    let path = get_model_path(name)?;
    if path.exists() {
        std::fs::remove_file(&path)?;
        log::info!("Deleted whisper model '{}' at {:?}", name, path);
    } else {
        anyhow::bail!("Model '{}' is not downloaded", name);
    }
    Ok(())
}
