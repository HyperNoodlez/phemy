use anyhow::Result;
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

use super::model_manager;

/// Transcribe audio using local whisper.cpp
pub async fn transcribe(samples: &[f32], model_name: &str, language: &str) -> Result<String> {
    let model_path = model_manager::get_model_path(model_name)?;

    if !model_path.exists() {
        anyhow::bail!(
            "Whisper model '{}' not found. Download it first.",
            model_name
        );
    }

    let samples = samples.to_vec();
    let language = language.to_string();
    let model_path_str = model_path.to_string_lossy().to_string();

    // Run whisper in a blocking thread to avoid blocking the async runtime
    tokio::task::spawn_blocking(move || {
        let ctx = WhisperContext::new_with_params(&model_path_str, WhisperContextParameters::default())
            .map_err(|e| anyhow::anyhow!("Failed to load whisper model: {}", e))?;

        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_language(Some(&language));
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        params.set_suppress_blank(true);
        params.set_single_segment(false);
        params.set_n_threads(num_cpus().min(4) as i32);

        let mut state = ctx.create_state()
            .map_err(|e| anyhow::anyhow!("Failed to create whisper state: {}", e))?;

        state.full(params, &samples)
            .map_err(|e| anyhow::anyhow!("Whisper transcription failed: {}", e))?;

        let num_segments = state.full_n_segments()
            .map_err(|e| anyhow::anyhow!("Failed to get segments: {}", e))?;

        let mut text = String::new();
        for i in 0..num_segments {
            if let Ok(segment) = state.full_get_segment_text(i) {
                text.push_str(&segment);
                text.push(' ');
            }
        }

        Ok(text.trim().to_string())
    })
    .await?
}

fn num_cpus() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(2)
}
