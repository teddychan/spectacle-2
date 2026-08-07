import Foundation

/// The app's own display name, read from the bundle rather than hardcoded.
///
/// This matters for debug builds. `scripts/run.sh` re-ids the local build as
/// `com.dragonapp.spectacle-2.debug` and renames it "Spectacle 2 Debug" so it can run beside an
/// installed release copy without colliding on TCC grants, the settings domain, or the menu bar.
/// A hardcoded name would defeat that in two ways: the About panel and the Settings window would
/// still claim to be the release build, and — worse — the Uninstall pane derives its
/// `Application Support` path from this name, so a debug build would offer to delete the *release*
/// build's data.
///
/// In a release build `CFBundleDisplayName` is "Spectacle 2", so this resolves to exactly the
/// string it replaced.
enum AppIdentity {
    static let displayName: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Spectacle 2"
}
