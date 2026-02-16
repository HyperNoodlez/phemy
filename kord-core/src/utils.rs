use std::path::PathBuf;

/// Get the models directory for whisper model storage.
/// Uses the data directory set by kord_init(), falling back to dirs::data_dir()/kord.
pub fn models_dir() -> anyhow::Result<PathBuf> {
    let base = crate::settings::get_data_dir().unwrap_or_else(|| {
        dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("kord")
    });
    let dir = base.join("models");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

/// Convert f32 PCM samples to WAV bytes (for cloud API uploads)
pub fn samples_to_wav(samples: &[f32], sample_rate: u32) -> anyhow::Result<Vec<u8>> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };

    let mut cursor = std::io::Cursor::new(Vec::new());
    {
        let mut writer = hound::WavWriter::new(&mut cursor, spec)?;
        for &sample in samples {
            let s = (sample * 32767.0).clamp(-32768.0, 32767.0) as i16;
            writer.write_sample(s)?;
        }
        writer.finalize()?;
    }

    Ok(cursor.into_inner())
}
