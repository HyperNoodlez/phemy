use anyhow::Result;
use enigo::{Direction, Enigo, Key, Keyboard, Settings as EnigoSettings};
use std::time::Duration;

use crate::settings::PasteMethod;

/// Paste text into the currently focused application via clipboard.
///
/// Strategy:
/// 1. Back up current clipboard contents
/// 2. Set clipboard to our text via arboard
/// 3. Simulate paste keystroke
/// 4. Restore original clipboard contents (best-effort)
pub fn paste_via_clipboard(
    text: &str,
    method: &PasteMethod,
    delay_ms: u64,
) -> Result<()> {
    // Small delay for focus to return to previous app
    std::thread::sleep(Duration::from_millis(delay_ms));

    // Back up current clipboard contents (best-effort)
    let mut clipboard = arboard::Clipboard::new()
        .map_err(|e| anyhow::anyhow!("Failed to access clipboard: {}", e))?;
    let previous_text = clipboard.get_text().ok();

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

    // Restore original clipboard contents after a short delay for paste to complete
    if let Some(prev) = previous_text {
        std::thread::sleep(Duration::from_millis(100));
        // Best-effort restore — don't fail the paste if this doesn't work
        let _ = clipboard.set_text(prev);
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
