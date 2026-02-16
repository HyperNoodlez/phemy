import SwiftUI
import Combine

@main
struct PhemyNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var theme = ThemeManager()

    /// Menu bar icon loaded from bundle resources, marked as template for light/dark adaptation
    private static let menuBarIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        // 44px source is @2x — set point size to 22 so it renders at correct menu bar size
        image.size = NSSize(width: 22, height: 22)
        return image
    }()

    /// App icon loaded from bundle resources
    static let appIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return nil }
        return image
    }()

    init() {
        // Set applicationIconImage early for About dialogs and window icons
        if let icon = Self.appIcon {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
                .frame(
                    minWidth: Spacing.minWindowWidth,
                    minHeight: Spacing.minWindowHeight
                )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 860, height: 600)

        MenuBarExtra {
            Button("Show Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("Quit Phemy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            if let icon = Self.menuBarIcon {
                Image(nsImage: icon)
            } else {
                Image(systemName: "waveform.circle.fill")
            }
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let recordingManager = RecordingManager()
    private let hotkeyManager = GlobalHotkeyManager()
    private var overlayPanel: RecordingOverlayPanel?
    private var phaseCancellable: AnyCancellable?
    private var settingsObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app appears in Dock (MenuBarExtra can default to accessory mode)
        NSApp.setActivationPolicy(.regular)

        // Set custom Dock tile icon (unbundled executables need explicit Dock tile update)
        if let icon = PhemyNativeApp.appIcon {
            NSApp.applicationIconImage = icon
            let dockTile = NSApp.dockTile
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: dockTile.size.width, height: dockTile.size.height))
            imageView.image = icon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            dockTile.contentView = imageView
            dockTile.display()
        }

        overlayPanel = RecordingOverlayPanel(recordingManager: recordingManager)

        // Observe phase changes to show/hide/resize overlay
        phaseCancellable = recordingManager.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }

        // Re-register hotkey whenever settings change
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsViewModel.settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let settings = notification.object as? AppSettings {
                self?.configureHotkey(settings: settings)
            }
        }

        // Register global hotkey from settings and sync theme to UserDefaults
        let settings = PhemyCore.shared.getSettings()
        configureHotkey(settings: settings)
        UserDefaults.standard.set(settings.theme.rawValue, forKey: "appTheme")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Hotkey Configuration

    func configureHotkey(settings: AppSettings) {
        let mode = settings.hotkeyMode

        switch mode {
        case .toggle:
            hotkeyManager.onPress = { [weak self] in
                self?.recordingManager.toggle()
            }
            hotkeyManager.onRelease = nil

        case .pushToTalk:
            hotkeyManager.onPress = { [weak self] in
                self?.recordingManager.startRecording()
            }
            hotkeyManager.onRelease = { [weak self] in
                self?.recordingManager.stopAndProcess()
            }
        }

        hotkeyManager.register(hotkey: settings.hotkey)
    }

    // MARK: - Overlay Lifecycle

    private func handlePhaseChange(_ phase: RecordingManager.Phase) {
        switch phase {
        case .idle:
            overlayPanel?.hide()
        case .recording, .processing:
            overlayPanel?.show()
            overlayPanel?.updateSize(expanded: false)
        case .ready:
            overlayPanel?.updateSize(expanded: true)
            overlayPanel?.makeKeyable()
        case .error:
            overlayPanel?.show()
            overlayPanel?.updateSize(expanded: true)
        }
    }
}
