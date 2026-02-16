/// Simple energy-based voice activity detection.
/// Trims silence from the beginning and end of audio.

const FRAME_SIZE: usize = 480; // 30ms at 16kHz
const ENERGY_THRESHOLD: f32 = 0.005;
const MIN_SPEECH_FRAMES: usize = 10;

/// Trim leading and trailing silence from audio samples
pub fn trim_silence(samples: &[f32]) -> &[f32] {
    if samples.is_empty() {
        return samples;
    }

    let frame_energies: Vec<f32> = samples
        .chunks(FRAME_SIZE)
        .map(|frame| {
            (frame.iter().map(|s| s * s).sum::<f32>() / frame.len() as f32).sqrt()
        })
        .collect();

    // Find first frame with speech
    let start_frame = frame_energies
        .iter()
        .position(|&e| e > ENERGY_THRESHOLD)
        .unwrap_or(0);

    // Find last frame with speech
    let end_frame = frame_energies
        .iter()
        .rposition(|&e| e > ENERGY_THRESHOLD)
        .unwrap_or(frame_energies.len().saturating_sub(1));

    // Require minimum speech duration
    if end_frame <= start_frame || (end_frame - start_frame) < MIN_SPEECH_FRAMES {
        return samples;
    }

    // Add small padding (2 frames) around speech
    let start_sample = start_frame.saturating_sub(2) * FRAME_SIZE;
    let end_sample = ((end_frame + 3) * FRAME_SIZE).min(samples.len());

    &samples[start_sample..end_sample]
}

/// Check if audio contains enough speech to be worth transcribing
pub fn has_speech(samples: &[f32]) -> bool {
    let speech_frames = samples
        .chunks(FRAME_SIZE)
        .filter(|frame| {
            let rms = (frame.iter().map(|s| s * s).sum::<f32>() / frame.len() as f32).sqrt();
            rms > ENERGY_THRESHOLD
        })
        .count();

    speech_frames >= MIN_SPEECH_FRAMES
}
