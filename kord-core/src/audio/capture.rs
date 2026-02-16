use cpal::traits::{DeviceTrait, StreamTrait};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

use super::device;

static RECORDING: AtomicBool = AtomicBool::new(false);

// cpal::Stream contains a raw pointer that isn't Send, so we wrap it
struct StreamHolder(Option<cpal::Stream>);
unsafe impl Send for StreamHolder {}
unsafe impl Sync for StreamHolder {}

static ACTIVE_STREAM: std::sync::LazyLock<Mutex<StreamHolder>> =
    std::sync::LazyLock::new(|| Mutex::new(StreamHolder(None)));

static SAMPLES_BUF: std::sync::LazyLock<Mutex<Option<Arc<Mutex<Vec<f32>>>>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));
static SAMPLE_RATE: std::sync::LazyLock<Mutex<Option<u32>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

/// C-compatible callback type for mic level updates.
/// Called from the audio thread with (rms, peak) values.
pub type MicLevelCallback = extern "C" fn(rms: f32, peak: f32);

/// Start recording from the given device name (or default if null).
/// The `mic_cb` function pointer is called on the audio thread with RMS and peak values.
pub fn start_recording(
    device_name: Option<&str>,
    mic_cb: Option<MicLevelCallback>,
) -> anyhow::Result<()> {
    if RECORDING.load(Ordering::Relaxed) {
        return Ok(());
    }

    let device = device::get_input_device(device_name)?;
    let config = device.default_input_config()?;

    let sample_rate = config.sample_rate().0;
    let channels = config.channels() as usize;

    let samples: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));
    let samples_clone = samples.clone();

    let stream = device.build_input_stream(
        &config.into(),
        move |data: &[f32], _: &cpal::InputCallbackInfo| {
            // Downmix to mono if multichannel
            let mono: Vec<f32> = if channels > 1 {
                data.chunks(channels)
                    .map(|frame| frame.iter().sum::<f32>() / channels as f32)
                    .collect()
            } else {
                data.to_vec()
            };

            // Calculate RMS and peak for visualization, invoke callback
            if !mono.is_empty() {
                if let Some(cb) = mic_cb {
                    let rms =
                        (mono.iter().map(|s| s * s).sum::<f32>() / mono.len() as f32).sqrt();
                    let peak = mono.iter().map(|s| s.abs()).fold(0.0f32, f32::max);
                    cb(rms, peak);
                }
            }

            // Store samples
            if let Ok(mut buf) = samples_clone.lock() {
                buf.extend_from_slice(&mono);
            }
        },
        |err| {
            log::error!("Audio stream error: {}", err);
        },
        None,
    )?;

    stream.play()?;

    // Store the stream so it stays alive
    {
        let mut holder = ACTIVE_STREAM.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        holder.0 = Some(stream);
    }

    // Store the samples buffer reference for retrieval
    *SAMPLES_BUF.lock().map_err(|e| anyhow::anyhow!("{}", e))? = Some(samples);
    *SAMPLE_RATE.lock().map_err(|e| anyhow::anyhow!("{}", e))? = Some(sample_rate);

    RECORDING.store(true, Ordering::Relaxed);
    log::info!("Recording started ({}Hz, {}ch)", sample_rate, channels);
    Ok(())
}

/// Stop recording and return (samples, sample_rate)
pub fn stop_recording() -> anyhow::Result<(Vec<f32>, u32)> {
    RECORDING.store(false, Ordering::Relaxed);

    // Drop the stream to stop recording
    {
        let mut holder = ACTIVE_STREAM.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        holder.0.take();
    }

    // Retrieve samples
    let samples = SAMPLES_BUF
        .lock()
        .map_err(|e| anyhow::anyhow!("{}", e))?
        .take()
        .and_then(|arc| arc.lock().ok().map(|s| s.clone()))
        .unwrap_or_default();

    let sample_rate = SAMPLE_RATE
        .lock()
        .map_err(|e| anyhow::anyhow!("{}", e))?
        .take()
        .unwrap_or(44100);

    log::info!(
        "Recording stopped: {} samples at {}Hz ({:.1}s)",
        samples.len(),
        sample_rate,
        samples.len() as f64 / sample_rate as f64
    );

    Ok((samples, sample_rate))
}

/// Stop recording without returning samples
pub fn stop_recording_sync() {
    if RECORDING.load(Ordering::Relaxed) {
        let _ = stop_recording();
    }
}

pub fn is_recording() -> bool {
    RECORDING.load(Ordering::Relaxed)
}
