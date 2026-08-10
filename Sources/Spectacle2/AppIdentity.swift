import DragonKit
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

    /// The bundle id Homebrew installed: the fallback for the running bundle's id in
    /// ``AppDelegate``, and the gate the cask token is issued against — deliberately not both at
    /// once, see ``homebrewCaskToken(actual:)``.
    static let releaseBundleID = "com.dragonapp.spectacle-2"

    /// The Homebrew cask token, or `nil` when this bundle is not the one brew installed.
    ///
    /// Spectacle ships as the cask `spectacle-2` — the token declared by `Casks/spectacle-2.rb` in
    /// teddychan/homebrew-tap, not inferred from the repo name. Homebrew never watches the
    /// filesystem, so an app that deletes itself leaves brew's receipt still claiming the cask is
    /// installed and `Caskroom/spectacle-2/<version>/Spectacle 2.app` a dangling symlink;
    /// `brew install --cask spectacle-2` then refuses outright — "already installed" — for an app
    /// that isn't there, pointing at nothing that would fix it. Naming the token lets the kit's
    /// post-exit shell run `brew uninstall --cask --force spectacle-2` and clear that record.
    ///
    /// **Never a flat token.** `brew uninstall --cask` is not bundle-scoped: it deletes whatever
    /// the receipt points at — the *release* app in /Applications — and `Casks/spectacle-2.rb`
    /// carries `uninstall quit: "com.dragonapp.spectacle-2"`, so it terminates that app first. The
    /// local Debug build, which `scripts/run.sh` re-ids `…spectacle-2.debug` precisely so it cannot
    /// touch the installed copy, must therefore issue nothing.
    ///
    /// The comparison is the kit's (``UninstallConfig/caskToken(_:ifBundleIs:actual:)``) rather
    /// than a local `==`, because it has to fail closed on the case hand-written versions got
    /// wrong: a debug id, another app's id and a *missing* id all return `nil`. Hence the raw
    /// `Bundle.main.bundleIdentifier` here, never ``AppDelegate``'s fallen-back `bundleID` — that
    /// one answers the release id for a build which can't state its own, which is exactly the build
    /// with no business authorising a delete. ice-2 and the sample app each shipped that bug.
    static func homebrewCaskToken(actual: String? = Bundle.main.bundleIdentifier) -> String? {
        UninstallConfig.caskToken("spectacle-2", ifBundleIs: releaseBundleID, actual: actual)
    }
}
