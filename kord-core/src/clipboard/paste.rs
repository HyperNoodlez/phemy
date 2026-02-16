use anyhow::Result;
use enigo::{Direction, Enigo, Key, Keyboard, Settings as EnigoSettings};
use std::time::Duration;

use crate::settings::PasteMethod;

/// Paste text into the currently focused application via clipboard.
///
/// Strategy:
/// 1. Set clipboard to our text via arboard
/// 2. Simulate paste keystroke
pub fn paste_via_clipboard(
    text: &str,
    method: &PasteMethod,
    delay_ms: u64,
) -> Result<()> {
    // Small delay for focus to return to previous app
    std::thread::sleep(Duration::from_millis(delay_ms));

    // Set clipboard using arboard
    let mut clipboard = arboard::Clipboard::new()
        .map_err(|e| anyhow::anyhow!("Failed to access clipboard: {}", e))?;
    clipboard
        .set_text(text)
        .map_err(|e| anyhow::anyhow!("Failed to set clipboard text: {}", e))?;

    std::thread::sleep(Duration::from_millis(50));

    match method {
        PasteMethod::TypeOut => {
            let mut enigo = Enigo::new(&EnigoSettings::default())
                .map_err(|e| anyhow::anyhow!("Failed to create enigo: {}", e))?;
            enigo
                .text(text)
                .map_err(|e| anyhow::anyhow!("Failed to type text: {}", e))?;
        }
        _ => {
            simulate_paste(method)?;
        }
    }

    Ok(())
}

fn simulate_paste(method: &PasteMethod) -> Result<()> {
    let mut enigo = Enigo::new(&EnigoSettings::default())
        .map_err(|e| anyhow::anyhow!("Failed to create enigo: {}", e))?;

    let modifier = if cfg!(target_os = "macos") {
        Key::Meta
    } else {
        Key::Control
    };

    match method {
        PasteMethod::CtrlV => {
            enigo
                .key(modifier, Direction::Press)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Unicode('v'), Direction::Click)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(modifier, Direction::Release)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
        }
        PasteMethod::CtrlShiftV => {
            enigo
                .key(modifier, Direction::Press)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Shift, Direction::Press)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Unicode('v'), Direction::Click)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Shift, Direction::Release)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(modifier, Direction::Release)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
        }
        PasteMethod::ShiftInsert => {
            enigo
                .key(Key::Shift, Direction::Press)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Other(0xFF63), Direction::Click) // Insert key
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            enigo
                .key(Key::Shift, Direction::Release)
                .map_err(|e| anyhow::anyhow!("{}", e))?;
        }
        PasteMethod::TypeOut => unreachable!(),
    }

    Ok(())
}
