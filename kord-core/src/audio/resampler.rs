use rubato::{FftFixedIn, Resampler};

const TARGET_SAMPLE_RATE: u32 = 16000;

/// Resample audio to 16kHz mono (required by Whisper)
pub fn resample_to_16khz(samples: &[f32], source_rate: u32) -> anyhow::Result<Vec<f32>> {
    if source_rate == TARGET_SAMPLE_RATE {
        return Ok(samples.to_vec());
    }

    let chunk_size = 1024;
    let mut resampler = FftFixedIn::<f32>::new(
        source_rate as usize,
        TARGET_SAMPLE_RATE as usize,
        chunk_size,
        1, // sub_chunks
        1, // channels (mono)
    )?;

    let mut output = Vec::new();
    let mut pos = 0;

    while pos + chunk_size <= samples.len() {
        let chunk = &samples[pos..pos + chunk_size];
        let result = resampler.process(&[chunk.to_vec()], None)?;
        output.extend_from_slice(&result[0]);
        pos += chunk_size;
    }

    // Handle remaining samples by padding with zeros
    if pos < samples.len() {
        let remaining = &samples[pos..];
        let mut padded = remaining.to_vec();
        padded.resize(chunk_size, 0.0);
        let result = resampler.process(&[padded], None)?;
        let expected_len = ((remaining.len() as f64 / source_rate as f64)
            * TARGET_SAMPLE_RATE as f64) as usize;
        let take = expected_len.min(result[0].len());
        output.extend_from_slice(&result[0][..take]);
    }

    Ok(output)
}
