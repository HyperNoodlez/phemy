use anyhow::Result;
use serde::Serialize;
use sha2::{Digest, Sha256};
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

/// (display_name, filename, size_mb, sha256_hex)
const MODELS: &[(&str, &str, u64, &str)] = &[
    ("tiny", "ggml-tiny.bin", 75, "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"),
    ("base", "ggml-base.bin", 142, "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"),
    ("small", "ggml-small.bin", 466, "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b"),
    ("medium", "ggml-medium.bin", 1500, "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208"),
    ("large-v3", "ggml-large-v3.bin", 3100, "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2"),
];

const HF_BASE_URL: &str =
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

pub fn get_model_path(name: &str) -> Result<PathBuf> {
    let models_dir = crate::utils::models_dir()?;
    let filename = MODELS
        .iter()
        .find(|(n, _, _, _)| *n == name)
        .map(|(_, f, _, _)| *f)
        .ok_or_else(|| anyhow::anyhow!("Unknown whisper model: {}", name))?;

    anyhow::ensure!(
        !filename.contains("..") && !filename.contains('/'),
        "Invalid model filename: {}",
        filename
    );

    Ok(models_dir.join(filename))
}

pub fn list_models() -> Result<Vec<WhisperModel>> {
    let models_dir = crate::utils::models_dir()?;

    Ok(MODELS
        .iter()
        .map(|(name, filename, size_mb, _sha256)| {
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
    let (_, filename, _, expected_sha256) = MODELS
        .iter()
        .find(|(n, _, _, _)| *n == name)
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
    let mut hasher = Sha256::new();

    let mut file = tokio::fs::File::create(&dest).await?;
    let mut stream = response.bytes_stream();

    use tokio::io::AsyncWriteExt;
    use futures_util::StreamExt;

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

    log::info!("Model '{}' downloaded and verified (SHA256 OK) at {:?}", name, dest);
    Ok(())
}

pub fn get_download_progress() -> Option<DownloadProgress> {
    DOWNLOAD_PROGRESS.lock().ok()?.clone()
}

/// Delete a downloaded whisper model by name.
pub fn delete_model(name: &str) -> Result<()> {
    let path = get_model_path(name)?;
    match std::fs::remove_file(&path) {
        Ok(_) => {
            log::info!("Deleted whisper model '{}' at {:?}", name, path);
            Ok(())
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            anyhow::bail!("Model '{}' is not downloaded", name)
        }
        Err(e) => Err(e.into()),
    }
}
