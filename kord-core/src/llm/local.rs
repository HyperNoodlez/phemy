#[cfg(feature = "llm-local")]
use llama_cpp_2::{
    context::params::LlamaContextParams,
    llama_backend::LlamaBackend,
    llama_batch::LlamaBatch,
    model::{params::LlamaModelParams, AddBos, LlamaChatMessage, LlamaChatTemplate, LlamaModel},
    sampling::LlamaSampler,
};

use anyhow::Result;
use std::num::NonZeroU32;
use std::path::Path;
use std::sync::Mutex;

#[cfg(feature = "llm-local")]
struct LoadedModel {
    backend: LlamaBackend,
    model: LlamaModel,
}

#[cfg(feature = "llm-local")]
// SAFETY: LlamaBackend and LlamaModel are internally synchronized by llama.cpp.
// We only access them through the LOADED_MODEL mutex which ensures single-threaded access.
unsafe impl Send for LoadedModel {}
unsafe impl Sync for LoadedModel {}

#[cfg(feature = "llm-local")]
static LOADED_MODEL: std::sync::LazyLock<Mutex<Option<LoadedModel>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

/// Load a GGUF model from disk with Metal GPU acceleration.
#[cfg(feature = "llm-local")]
pub fn load_model(path: &Path) -> Result<()> {
    log::info!("Loading local LLM from {:?}", path);

    if !path.exists() {
        anyhow::bail!("Model file not found: {:?}", path);
    }

    let backend = LlamaBackend::init()
        .map_err(|e| anyhow::anyhow!("Failed to init llama backend: {}", e))?;

    let model_params = LlamaModelParams::default()
        .with_n_gpu_layers(1000); // Offload all layers to Metal GPU

    let model = LlamaModel::load_from_file(&backend, path, &model_params)
        .map_err(|e| anyhow::anyhow!("Failed to load model: {}", e))?;

    log::info!(
        "Model loaded: {} params, {}MB",
        model.n_params(),
        model.size() / (1024 * 1024)
    );

    if let Ok(mut loaded) = LOADED_MODEL.lock() {
        *loaded = Some(LoadedModel { backend, model });
    }

    Ok(())
}

/// Run prompt optimization using the loaded local model.
#[cfg(feature = "llm-local")]
pub fn optimize(transcript: &str, system_prompt: &str) -> Result<String> {
    let guard = LOADED_MODEL
        .lock()
        .map_err(|e| anyhow::anyhow!("Lock error: {}", e))?;

    let loaded = guard
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("No local LLM model loaded"))?;

    // Build chat messages
    let messages = vec![
        LlamaChatMessage::new("system".to_string(), system_prompt.to_string())
            .map_err(|e| anyhow::anyhow!("Failed to create system message: {}", e))?,
        LlamaChatMessage::new("user".to_string(), transcript.to_string())
            .map_err(|e| anyhow::anyhow!("Failed to create user message: {}", e))?,
    ];

    // Apply chat template
    let fallback_chatml = "{% for message in messages %}<|im_start|>{{ message.role }}\n{{ message.content }}<|im_end|>\n{% endfor %}<|im_start|>assistant\n";
    let template = loaded
        .model
        .chat_template(None)
        .unwrap_or_else(|_| {
            LlamaChatTemplate::new(fallback_chatml)
                .expect("Fallback template is valid")
        });

    let prompt = loaded
        .model
        .apply_chat_template(&template, &messages, true)
        .map_err(|e| anyhow::anyhow!("Failed to apply chat template: {}", e))?;

    // Create context
    let ctx_params = LlamaContextParams::default()
        .with_n_ctx(Some(NonZeroU32::new(2048).unwrap()))
        .with_n_batch(512);

    let mut ctx = loaded
        .model
        .new_context(&loaded.backend, ctx_params)
        .map_err(|e| anyhow::anyhow!("Failed to create context: {}", e))?;

    // Tokenize
    let tokens = loaded
        .model
        .str_to_token(&prompt, AddBos::Always)
        .map_err(|e| anyhow::anyhow!("Failed to tokenize: {}", e))?;

    // Create batch and add prompt tokens
    let mut batch = LlamaBatch::new(2048, 1);
    for (i, token) in tokens.iter().enumerate() {
        let is_last = i == tokens.len() - 1;
        batch
            .add(*token, i as i32, &[0], is_last)
            .map_err(|e| anyhow::anyhow!("Failed to add token to batch: {}", e))?;
    }

    // Process prompt
    ctx.decode(&mut batch)
        .map_err(|e| anyhow::anyhow!("Failed to decode prompt: {}", e))?;

    // Sample with temp=0.3 for focused but not fully deterministic output
    let mut sampler = LlamaSampler::chain_simple([
        LlamaSampler::top_k(40),
        LlamaSampler::top_p(0.95, 1),
        LlamaSampler::temp(0.3),
        LlamaSampler::dist(42),
    ]);

    let mut output = String::new();
    let max_tokens = 1024;
    let mut decoder = encoding_rs::UTF_8.new_decoder();
    let mut n_cur = tokens.len() as i32;

    for _ in 0..max_tokens {
        let new_token = sampler.sample(&ctx, batch.n_tokens() - 1);
        sampler.accept(new_token);

        if loaded.model.is_eog_token(new_token) {
            break;
        }

        let token_str = loaded
            .model
            .token_to_piece(new_token, &mut decoder, true, None)
            .map_err(|e| anyhow::anyhow!("Failed to convert token: {}", e))?;

        output.push_str(&token_str);

        batch.clear();
        batch
            .add(new_token, n_cur, &[0], true)
            .map_err(|e| anyhow::anyhow!("Failed to add token: {}", e))?;
        n_cur += 1;

        ctx.decode(&mut batch)
            .map_err(|e| anyhow::anyhow!("Failed to decode: {}", e))?;
    }

    // Strip Qwen3 thinking block if present
    let result = output.trim();
    let result = if let Some(think_end) = result.find("</think>") {
        result[think_end + "</think>".len()..].trim()
    } else if result.starts_with("<think>") {
        // Thinking block never closed (token budget exhausted) — discard it all
        ""
    } else {
        result
    };

    Ok(result.to_string())
}

/// Unload the model to free memory.
#[cfg(feature = "llm-local")]
pub fn unload() {
    if let Ok(mut loaded) = LOADED_MODEL.lock() {
        *loaded = None;
        log::info!("Local LLM model unloaded");
    }
}

/// Check if a model is currently loaded.
#[cfg(feature = "llm-local")]
pub fn is_loaded() -> bool {
    LOADED_MODEL
        .lock()
        .map(|l| l.is_some())
        .unwrap_or(false)
}

// Stub implementations when llm-local feature is disabled

#[cfg(not(feature = "llm-local"))]
pub fn load_model(_path: &Path) -> Result<()> {
    anyhow::bail!("Local LLM support not compiled (enable 'llm-local' feature)")
}

#[cfg(not(feature = "llm-local"))]
pub fn optimize(_transcript: &str, _system_prompt: &str) -> Result<String> {
    anyhow::bail!("Local LLM support not compiled (enable 'llm-local' feature)")
}

#[cfg(not(feature = "llm-local"))]
pub fn unload() {}

#[cfg(not(feature = "llm-local"))]
pub fn is_loaded() -> bool {
    false
}
