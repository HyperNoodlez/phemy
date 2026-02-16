use cpal::traits::{DeviceTrait, HostTrait};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct AudioDevice {
    pub name: String,
    pub is_default: bool,
}

pub fn list_input_devices() -> anyhow::Result<Vec<AudioDevice>> {
    let host = cpal::default_host();
    let default_device = host.default_input_device();
    let default_name = default_device
        .as_ref()
        .and_then(|d| d.name().ok())
        .unwrap_or_default();

    let mut devices = Vec::new();

    for device in host.input_devices()? {
        if let Ok(name) = device.name() {
            devices.push(AudioDevice {
                is_default: name == default_name,
                name,
            });
        }
    }

    Ok(devices)
}

pub fn get_input_device(name: Option<&str>) -> anyhow::Result<cpal::Device> {
    let host = cpal::default_host();

    match name {
        Some(name) => {
            for device in host.input_devices()? {
                if device.name().ok().as_deref() == Some(name) {
                    return Ok(device);
                }
            }
            anyhow::bail!("Audio device '{}' not found", name)
        }
        None => host
            .default_input_device()
            .ok_or_else(|| anyhow::anyhow!("No default input device available")),
    }
}
