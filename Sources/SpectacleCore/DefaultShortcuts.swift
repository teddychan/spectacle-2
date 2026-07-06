public enum DefaultShortcuts {
    public typealias Map = [WindowAction: Shortcut]

    public static let map: Map = {
        func s(_ code: UInt16, _ mods: ModifierFlags) -> Shortcut { Shortcut(keyCode: code, modifiers: mods) }
        let om: ModifierFlags = [.option, .command]
        let cm: ModifierFlags = [.control, .command]
        let csm: ModifierFlags = [.control, .shift, .command]
        let co: ModifierFlags = [.control, .option]
        let com: ModifierFlags = [.control, .option, .command]
        let cos: ModifierFlags = [.control, .option, .shift]
        return [
            .center: s(8, om), .fullscreen: s(3, om),
            .leftHalf: s(123, om), .rightHalf: s(124, om),
            .topHalf: s(126, om), .bottomHalf: s(125, om),
            .upperLeft: s(123, cm), .upperRight: s(124, cm),
            .lowerLeft: s(123, csm), .lowerRight: s(124, csm),
            .nextThird: s(124, co), .previousThird: s(123, co),
            .nextDisplay: s(124, com), .previousDisplay: s(123, com),
            .makeLarger: s(124, cos), .makeSmaller: s(123, cos),
            .undo: s(6, om), .redo: s(6, [.option, .shift, .command]),
        ]
    }()
}
