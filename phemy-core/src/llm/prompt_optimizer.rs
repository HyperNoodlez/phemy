use anyhow::Result;
use serde::Serialize;

use crate::settings::{PromptMode, Settings};
use super::{client, prompt_templates};


#[derive(Debug, Clone, Serialize)]
pub struct OptimizationResult {
    pub raw_transcript: String,
    pub optimized_prompt: String,
    pub mode: String,
    pub provider: Option<String>,
}

/// Optimize a raw transcript into a polished prompt
pub async fn optimize(transcript: &str, settings: &Settings) -> Result<OptimizationResult> {
    let transcript = transcript.trim();

    if transcript.is_empty() {
        return Ok(OptimizationResult {
            raw_transcript: String::new(),
            optimized_prompt: String::new(),
            mode: format!("{:?}", settings.prompt_mode),
            provider: None,
        });
    }

    // Raw mode bypasses LLM entirely
    if settings.prompt_mode == PromptMode::Raw {
        return Ok(OptimizationResult {
            raw_transcript: transcript.to_string(),
            optimized_prompt: transcript.to_string(),
            mode: "raw".to_string(),
            provider: None,
        });
    }

    // Get system prompt (built-in or custom)
    let system_prompt = if settings.prompt_mode == PromptMode::Custom {
        settings
            .custom_system_prompt
            .as_deref()
            .unwrap_or("Clean up this voice transcript into a clear prompt. Output only the result.")
    } else {
        prompt_templates::get_system_prompt(&settings.prompt_mode)
    };

    // Call LLM
    let optimized = match client::chat_completion(system_prompt, transcript, settings).await {
        Ok(result) => result.trim().to_string(),
        Err(e) => {
            log::warn!("LLM optimization failed, using raw transcript: {}", e);
            return Ok(OptimizationResult {
                raw_transcript: transcript.to_string(),
                optimized_prompt: transcript.to_string(),
                mode: format!("{:?}", settings.prompt_mode),
                provider: Some(format!("local (failed: {})", e)),
            });
        }
    };

    Ok(OptimizationResult {
        raw_transcript: transcript.to_string(),
        optimized_prompt: optimized,
        mode: format!("{:?}", settings.prompt_mode).to_lowercase(),
        provider: Some("local".to_string()),
    })
}
