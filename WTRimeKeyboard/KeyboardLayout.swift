import Foundation

enum KeyboardMode: Equatable {
    case fullQwerty
    case nineGrid
    case emoji
}

struct KeyboardRow {
    let keys: [KeyboardKey]
}

struct KeyboardKey: Hashable {
    enum Kind {
        case character
        case multiCharacter
        case delete
        case space
        case returnKey
        case shift
        case modeSwitch
        case emojiToggle
        case globe
        case punctuation
    }

    let identifier: String
    let title: String
    let subtitle: String?
    let output: String
    let kind: Kind
    let alternatives: [String]

    init(identifier: String, title: String, subtitle: String? = nil, output: String = "", kind: Kind, alternatives: [String] = []) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.output = output
        self.kind = kind
        self.alternatives = alternatives
    }
}

struct KeyboardLayoutProvider {
    private let qwertyRows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    private let nineGridRows = [
        [["q", "w", "e"], ["r", "t", "y"], ["u", "i", "o"]],
        [["p", "a", "s"], ["d", "f", "g"], ["h", "j", "k"]],
        [["l", "z", "x"], ["c", "v", "b"], ["n", "m"]]
    ]

    func layout(for mode: KeyboardMode, uppercase: Bool, emojiSymbols: [String] = []) -> [KeyboardRow] {
        switch mode {
        case .fullQwerty:
            return qwertyLayout(uppercase: uppercase)
        case .nineGrid:
            return nineGridLayout()
        case .emoji:
            return emojiLayout(symbols: emojiSymbols)
        }
    }

    private func qwertyLayout(uppercase: Bool) -> [KeyboardRow] {
        var rows: [KeyboardRow] = []

        for row in qwertyRows {
            let keys = row.map { letter -> KeyboardKey in
                let displayed = uppercase ? letter.uppercased() : letter.lowercased()
                return KeyboardKey(
                    identifier: letter,
                    title: displayed,
                    output: displayed,
                    kind: .character
                )
            }
            rows.append(KeyboardRow(keys: keys))
        }

        var thirdRowKeys = rows[2].keys
        thirdRowKeys.insert(KeyboardKey(identifier: "shift", title: "⇧", kind: .shift), at: 0)
        thirdRowKeys.append(KeyboardKey(identifier: "delete", title: "⌫", kind: .delete))
        rows[2] = KeyboardRow(keys: thirdRowKeys)

        let bottomRow = KeyboardRow(keys: [
            KeyboardKey(identifier: "modeSwitch", title: "九宫/全", kind: .modeSwitch),
            KeyboardKey(identifier: "emojiToggle", title: "😊", kind: .emojiToggle),
            KeyboardKey(identifier: "comma", title: "，", output: "，", kind: .punctuation),
            KeyboardKey(identifier: "space", title: "空格", kind: .space),
            KeyboardKey(identifier: "globe", title: "🌐", kind: .globe),
            KeyboardKey(identifier: "period", title: "。", output: "。", kind: .punctuation),
            KeyboardKey(identifier: "return", title: "发送", kind: .returnKey)
        ])
        rows.append(bottomRow)
        return rows
    }

    private func nineGridLayout() -> [KeyboardRow] {
        var rows: [KeyboardRow] = []
        for (rowIndex, row) in nineGridRows.enumerated() {
            let keys = row.enumerated().map { columnIndex, letters -> KeyboardKey in
                let identifier = "nine_\(rowIndex)_\(columnIndex)"
                let title = letters.joined().uppercased()
                return KeyboardKey(
                    identifier: identifier,
                    title: title,
                    output: letters.first ?? "",
                    kind: .multiCharacter,
                    alternatives: letters
                )
            }
            rows.append(KeyboardRow(keys: keys))
        }

        let bottomRow = KeyboardRow(keys: [
            KeyboardKey(identifier: "modeSwitch", title: "九宫/全", kind: .modeSwitch),
            KeyboardKey(identifier: "emojiToggle", title: "😊", kind: .emojiToggle),
            KeyboardKey(identifier: "space", title: "空格", kind: .space),
            KeyboardKey(identifier: "delete", title: "⌫", kind: .delete),
            KeyboardKey(identifier: "globe", title: "🌐", kind: .globe),
            KeyboardKey(identifier: "return", title: "发送", kind: .returnKey)
        ])
        rows.append(bottomRow)
        return rows
    }

    private func emojiLayout(symbols: [String]) -> [KeyboardRow] {
        guard !symbols.isEmpty else {
            return [KeyboardRow(keys: [KeyboardKey(identifier: "emojiEmpty", title: "暂无表情", kind: .emojiToggle)])]
        }

        var rows: [KeyboardRow] = []
        let chunkSize = 8
        var currentIndex = 0
        while currentIndex < symbols.count {
            let slice = Array(symbols[currentIndex..<min(currentIndex + chunkSize, symbols.count)])
            let keys = slice.enumerated().map { offset, emoji in
                KeyboardKey(
                    identifier: "emoji_\(currentIndex + offset)",
                    title: emoji,
                    output: emoji,
                    kind: .character
                )
            }
            rows.append(KeyboardRow(keys: keys))
            currentIndex += chunkSize
        }

        let bottomRow = KeyboardRow(keys: [
            KeyboardKey(identifier: "emojiModeSwitch", title: "ABC", kind: .emojiToggle),
            KeyboardKey(identifier: "emojiSpace", title: "空格", kind: .space),
            KeyboardKey(identifier: "emojiGlobe", title: "🌐", kind: .globe),
            KeyboardKey(identifier: "emojiReturn", title: "发送", kind: .returnKey)
        ])
        rows.append(bottomRow)
        return rows
    }
}
