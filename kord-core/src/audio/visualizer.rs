use rustfft::{num_complex::Complex, FftPlanner};

const NUM_BANDS: usize = 8;

/// Compute frequency band levels from audio samples for waveform visualization.
/// Returns levels for NUM_BANDS frequency bands, each normalized to 0.0-1.0.
pub fn compute_band_levels(samples: &[f32]) -> Vec<f32> {
    if samples.len() < 64 {
        return vec![0.0; NUM_BANDS];
    }

    // Use last 1024 samples (or whatever is available)
    let fft_size = 1024.min(samples.len()).next_power_of_two();
    let start = samples.len().saturating_sub(fft_size);
    let window: Vec<f32> = samples[start..start + fft_size]
        .iter()
        .enumerate()
        .map(|(i, &s)| {
            // Hann window
            let w = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / fft_size as f32).cos());
            s * w
        })
        .collect();

    // FFT
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(fft_size);
    let mut buffer: Vec<Complex<f32>> = window
        .iter()
        .map(|&s| Complex::new(s, 0.0))
        .collect();
    fft.process(&mut buffer);

    // Only use first half (positive frequencies)
    let half = fft_size / 2;
    let magnitudes: Vec<f32> = buffer[..half]
        .iter()
        .map(|c| c.norm() / half as f32)
        .collect();

    // Split into frequency bands (logarithmic distribution)
    let mut levels = Vec::with_capacity(NUM_BANDS);
    for i in 0..NUM_BANDS {
        let start = (half as f32 * (i as f32 / NUM_BANDS as f32).powi(2)) as usize;
        let end = (half as f32 * ((i + 1) as f32 / NUM_BANDS as f32).powi(2)) as usize;
        let end = end.max(start + 1).min(half);

        let avg = magnitudes[start..end].iter().sum::<f32>() / (end - start) as f32;
        // Normalize with some headroom
        levels.push((avg * 10.0).min(1.0));
    }

    levels
}
