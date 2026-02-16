use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::settings::Settings;
use super::{local, llm_model_manager};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

/// Send a chat completion request using the local LLM.
pub async fn chat_completion(
    system_prompt: &str,
    user_message: &str,
    settings: &Settings,
) -> Result<String> {
    local_completion(system_prompt, user_message, settings)
}

fn local_completion(
    system_prompt: &str,
    user_message: &str,
    settings: &Settings,
) -> Result<String> {
    // Load model on first call if not already loaded
    if !local::is_loaded() {
        let model_name = settings
            .local_llm_model
            .as_deref()
            .unwrap_or("qwen3-4b-instruct-q4km");
        let model_path = llm_model_manager::get_model_path(model_name)?;
        if !model_path.exists() {
            anyhow::bail!(
                "Local LLM model '{}' not downloaded. Download it from Settings > LLM.",
                model_name
            );
        }
        local::load_model(&model_path)?;
    }

    local::optimize(user_message, system_prompt)
}
