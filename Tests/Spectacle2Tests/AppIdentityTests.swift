import Testing
import Foundation
@testable import Spectacle2

// The Homebrew cask token is the one uninstall decision that is NOT bundle-scoped, so it is the
// one where getting it wrong is destructive.
//
// `brew uninstall --cask spectacle-2 --force` deletes whatever brew's receipt points at — the
// release app in /Applications — and `Casks/spectacle-2.rb` carries
// `uninstall quit: "com.dragonapp.spectacle-2"`, so it terminates that app first. Every build
// Homebrew did not install therefore has to issue no token at all: the local Debug build that
// `scripts/run.sh` re-ids `…spectacle-2.debug` precisely so it cannot touch the installed copy,
// and a build that cannot state its own id.
//
// That last case is not hypothetical. ice-2 and the sample app both wrote
// `Bundle.main.bundleIdentifier ?? releaseBundleID`, and so answered the release id for exactly the
// build least entitled to authorise a delete.

@Suite struct AppIdentityHomebrewCaskTests {

    @Test func theInstalledReleaseGetsTheToken() {
        #expect(AppIdentity.homebrewCaskToken(actual: AppIdentity.releaseBundleID) == "spectacle-2")
    }

    @Test func theDebugBuildGetsNothing() {
        #expect(AppIdentity.homebrewCaskToken(
            actual: "\(AppIdentity.releaseBundleID).debug") == nil)
    }

    @Test func aBuildWithNoBundleIDGetsNothing() {
        #expect(AppIdentity.homebrewCaskToken(actual: nil) == nil)
        // Two empty strings must not match each other either.
        #expect(AppIdentity.homebrewCaskToken(actual: "") == nil)
    }

    @Test func anotherAppsBundleIDGetsNothing() {
        #expect(AppIdentity.homebrewCaskToken(actual: "com.dragonapp.clipmenu-2") == nil)
    }

    /// The uninstall pane's `Application Support` path is derived from this, so a hardcoded name
    /// would have a Debug build offering to delete the release build's data — the reason
    /// `AppIdentity` exists at all. Under the test bundle there is no `CFBundleDisplayName`, so
    /// this exercises the fallback chain rather than the release value.
    @Test func displayNameIsNeverEmpty() {
        #expect(!AppIdentity.displayName.isEmpty)
    }
}
