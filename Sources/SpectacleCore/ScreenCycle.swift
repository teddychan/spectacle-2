/// Pure display-cycling index math. The app maps its ordered `NSScreen` list onto this so the
/// wraparound logic can be unit-tested without any real displays.
public enum ScreenCycle {
    /// Destination index when cycling among `count` ordered screens from `current` by
    /// `direction` (+1 = next, -1 = previous), wrapping around. Returns `nil` when there are
    /// fewer than two screens (nothing to cycle to).
    public static func destinationIndex(count: Int, current: Int, direction: Int) -> Int? {
        guard count > 1 else { return nil }
        return ((current + direction) % count + count) % count
    }
}
