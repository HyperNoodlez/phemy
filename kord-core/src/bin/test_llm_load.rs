fn main() {
    let model_path = format!(
        "{}/Library/Application Support/com.kord.native/models/llm/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        std::env::var("HOME").unwrap()
    );

    println!("Testing LLM model loading...");
    println!("whisper-local feature: {}", cfg!(feature = "whisper-local"));
    println!("llm-local feature: {}", cfg!(feature = "llm-local"));

    #[cfg(feature = "llm-local")]
    {
        use llama_cpp_2::llama_backend::LlamaBackend;
        use llama_cpp_2::model::params::LlamaModelParams;
        use llama_cpp_2::model::LlamaModel;

        let backend = LlamaBackend::init().expect("Failed to init backend");
        let model_params = LlamaModelParams::default().with_n_gpu_layers(1000);

        match LlamaModel::load_from_file(&backend, std::path::Path::new(&model_path), &model_params)
        {
            Ok(model) => {
                println!(
                    "SUCCESS! Model loaded: {} params, {}MB",
                    model.n_params(),
                    model.size() / (1024 * 1024)
                );
            }
            Err(e) => {
                eprintln!("FAILED to load model: {}", e);
                std::process::exit(1);
            }
        }
    }

    #[cfg(not(feature = "llm-local"))]
    {
        eprintln!("llm-local feature not enabled!");
        std::process::exit(1);
    }
}
