import AppKit
import SwiftUI
import os.log

private let overlayLog = Logger(subsystem: "com.labgarge.kord", category: "Overlay")

/// A transparent, borderless, always-on-top panel for the recording overlay.
/// Non-activating so it doesn't steal focus from the app being dictated into.
final class RecordingOverlayPanel {
    private var panel: NSPanel?
    private var recordingManager: RecordingManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }

    /// Show the overlay panel at the bottom-center of the main screen.
    func show() {
        if panel != nil { return }

        let contentView = RecordingOverlayView(manager: recordingManager)
        let hostingView = NSHostingView(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView = hostingView
        hostingView.wantsLayer = true

        positionPanel(panel, expanded: false)
        panel.orderFront(nil)
        self.panel = panel
    }

    /// Update panel size based on phase.
    func updateSize(expanded: Bool) {
        guard let panel = panel else { return }
        let newWidth: CGFloat = expanded ? 400 : 340
        let newHeight: CGFloat = expanded ? 200 : 80
        let newFrame = NSRect(
            x: panel.frame.midX - newWidth / 2,
            y: panel.frame.origin.y,
            width: newWidth,
            height: newHeight
        )
        panel.setFrame(newFrame, display: true, animate: true)
    }

    /// Install a CGEvent tap to intercept Enter/Escape system-wide.
    ///
    /// This uses `.cgSessionEventTap` to intercept ALL keyDown events because the overlay
    /// panel is non-activating (`.nonactivatingPanel`) and therefore cannot become the key
    /// window. Only Return (keyCode 36) and Escape (keyCode 53) are consumed; all other
    /// keys pass through unmodified. The tap is removed when the overlay is hidden.
    func makeKeyable() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                // Re-enable if the system disabled the tap due to timeout
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userInfo = userInfo {
                        let panel = Unmanaged<RecordingOverlayPanel>.fromOpaque(userInfo).takeUnretainedValue()
                        if let tap = panel.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passRetained(event)
                }
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let panel = Unmanaged<RecordingOverlayPanel>.fromOpaque(userInfo).takeUnretainedValue()

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 36 { // Return
                    DispatchQueue.main.async { panel.recordingManager.paste() }
                    return nil // consume — don't deliver to frontmost app
                } else if keyCode == 53 { // Escape
                    DispatchQueue.main.async { panel.recordingManager.dismiss() }
                    return nil
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: refcon
        )

        guard let tap = eventTap else {
            overlayLog.error("CGEvent.tapCreate returned nil — Accessibility permission not granted")
            // Notify the user that keyboard shortcuts won't work
            DispatchQueue.main.async {
                self.recordingManager.accessibilityDenied = true
            }
            return
        }
        overlayLog.info("Event tap installed for Enter/Escape interception")

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Hide and destroy the panel.
    func hide() {
        removeEventTap()
        panel?.orderOut(nil)
        panel = nil
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func positionPanel(_ panel: NSPanel, expanded: Bool) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let width: CGFloat = expanded ? 400 : 340
        let height: CGFloat = expanded ? 200 : 80
        let x = screenFrame.midX - width / 2
        let y = screenFrame.origin.y + 60
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
