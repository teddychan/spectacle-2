import Foundation
import DragonKit

/// Spectacle 2's persisted app settings. A plain `Codable` value stored in a named
/// UserDefaults suite via ``DragonSettingsStore`` — so Backup & Restore can snapshot and
/// restore it wholesale. The window-action shortcut map is added in a later feature commit;
/// this scaffold holds only the shell-level options.
struct AppSettings: Codable, Sendable, Equatable {
    var launchAtLogin = false
    var showInMenuBar = true
}

extension Notification.Name {
    /// Posted (with a `Bool` object) when "Show in menu bar" changes, so the AppDelegate can
    /// show/hide the status item.
    static let spectacleShowInMenuBarChanged = Notification.Name("spectacleShowInMenuBarChanged")

    /// Posted (with a `Bool` object) while a shortcut recorder is capturing. The AppDelegate
    /// suspends the global hot keys during recording so pressing an already-bound combo lands in
    /// the recorder instead of firing that action, then restores them when recording ends.
    static let spectacleShortcutRecordingChanged = Notification.Name("spectacleShortcutRecordingChanged")
}

/// Observable bridge between the settings UI and persistence. Each setter persists via the
/// store and applies its side effect (login-item registration, menu-bar visibility).
@MainActor
@Observable
final class SettingsModel {
    /// A dedicated suite (distinct from the app's bundle-id domain) so a backup captures only
    /// app settings — not the backup pane's own preferences.
    static let suiteName = (Bundle.main.bundleIdentifier ?? "com.dragonapp.spectacle-2") + ".settings"

    private let store: DragonSettingsStore<AppSettings>
    private var settings: AppSettings {
        didSet { store.save(settings) }
    }

    init() {
        let store = DragonSettingsStore(suiteName: Self.suiteName, defaultValue: AppSettings())
        self.store = store
        self.settings = store.load()
        // Reconcile the OS login-item state with the persisted preference on launch.
        LoginItem.setEnabled(settings.launchAtLogin)
    }

    var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set {
            settings.launchAtLogin = newValue
            LoginItem.setEnabled(newValue)
        }
    }

    var showInMenuBar: Bool {
        get { settings.showInMenuBar }
        set {
            settings.showInMenuBar = newValue
            NotificationCenter.default.post(name: .spectacleShowInMenuBarChanged, object: newValue)
        }
    }
}
