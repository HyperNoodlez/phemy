use anyhow::Result;
use serde::Serialize;

use crate::settings::Settings;

#[derive(Debug, Clone, Serialize)]
pub struct TranscriptionResult {
    pub text: String,
    pub language: Option<String>,
    pub duration_secs: f64,
}

/// Transcribe audio using local Whisper
pub async fn transcribe(
    samples: &[f32],
    sample_rate: u32,
    settings: &Settings,
) -> Result<TranscriptionResult> {
    // Resample to 16kHz if needed
    let resampled = crate::audio::resampler::resample_to_16khz(samples, sample_rate)?;

    // Trim silence
    let trimmed = crate::audio::vad::trim_silence(&resampled);

    if !crate::audio::vad::has_speech(trimmed) {
        return Ok(TranscriptionResult {
            text: String::new(),
            language: Some(settings.language.clone()),
            duration_secs: trimmed.len() as f64 / 16000.0,
        });
    }

    let duration_secs = trimmed.len() as f64 / 16000.0;

    #[cfg(feature = "whisper-local")]
    let text = super::whisper_local::transcribe(trimmed, &settings.whisper_model, &settings.language)
        .await?;

    #[cfg(not(feature = "whisper-local"))]
    let text = {
        anyhow::bail!(
            "Local whisper not available. Build with --features whisper-local."
        );
        #[allow(unreachable_code)]
        String::new()
    };

    Ok(TranscriptionResult {
        text,
        language: Some(settings.language.clone()),
        duration_secs,
    })
}
