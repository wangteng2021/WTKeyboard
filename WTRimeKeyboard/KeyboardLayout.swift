import Foundation
import CoreGraphics

enum KeyboardMode: Equatable {
    case fullQwerty
    case nineGrid
    case emoji
}

struct KeyboardRow {
    let keys: [KeyboardKey]
    let leadingInset: CGFloat
    let trailingInset: CGFloat

    init(keys: [KeyboardKey], leadingInset: CGFloat = 0, trailingInset: CGFloat = 0) {
        self.keys = keys
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
    }
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
    let widthMultiplier: CGFloat

    init(
        identifier: String,
        title: String,
        subtitle: String? = nil,
        output: String = "",
        kind: Kind,
        alternatives: [String] = [],
        widthMultiplier: CGFloat = 1
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.output = output
        self.kind = kind
        self.alternatives = alternatives
        self.widthMultiplier = widthMultiplier
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

        for (index, row) in qwertyRows.enumerated() {
            let keys = row.map { letter -> KeyboardKey in
                let displayed = uppercase ? letter.uppercased() : letter.lowercased()
                return KeyboardKey(
                    identifier: letter,
                    title: displayed,
                    output: displayed,
                    kind: .character
                )
            }
            let inset: CGFloat
            switch index {
            case 1:
                inset = 10
            case 2:
                inset = 20
            default:
                inset = 0
            }
            rows.append(KeyboardRow(keys: keys, leadingInset: inset, trailingInset: inset))
        }

        var thirdRowKeys = rows[2].keys
        thirdRowKeys.insert(
            KeyboardKey(identifier: "shift", title: "⇧", kind: .shift, widthMultiplier: 1.4),
            at: 0
        )
        thirdRowKeys.append(
            KeyboardKey(identifier: "delete", title: "⌫", kind: .delete, widthMultiplier: 1.4)
        )
        rows[2] = KeyboardRow(keys: thirdRowKeys, leadingInset: 20, trailingInset: 20)

        let bottomRow = KeyboardRow(keys: [
            KeyboardKey(identifier: "modeSwitch", title: "九宫/全", kind: .modeSwitch, widthMultiplier: 1.5),
            KeyboardKey(identifier: "emojiToggle", title: "😊", kind: .emojiToggle, widthMultiplier: 1.2),
            KeyboardKey(identifier: "comma", title: "，", output: "，", kind: .punctuation),
            KeyboardKey(identifier: "space", title: "空格", kind: .space, widthMultiplier: 4.2),
            KeyboardKey(identifier: "globe", title: "🌐", kind: .globe, widthMultiplier: 1.2),
            KeyboardKey(identifier: "period", title: "。", output: "。", kind: .punctuation),
            KeyboardKey(identifier: "return", title: "发送", kind: .returnKey, widthMultiplier: 1.6)
        ], leadingInset: 6, trailingInset: 6)
        rows.append(bottomRow)
        return rows
    }

    private func nineGridLayout() -> [KeyboardRow] {
        let firstRow = KeyboardRow(
            keys: [
                KeyboardKey(
                    identifier: "nine_symbols",
                    title: "符",
                    subtitle: "1",
                    output: "。",
                    kind: .punctuation,
                    alternatives: ["。", "？", "！", "，", ".", "?", "!"],
                    widthMultiplier: 1.1
                ),
                makeNineKey(identifier: "nine_2", digit: "2", letters: "ABC"),
                makeNineKey(identifier: "nine_3", digit: "3", letters: "DEF")
            ],
            leadingInset: 6,
            trailingInset: 6
        )

        let secondRow = KeyboardRow(
            keys: [
                makeNineKey(identifier: "nine_4", digit: "4", letters: "GHI"),
                makeNineKey(identifier: "nine_5", digit: "5", letters: "JKL"),
                makeNineKey(identifier: "nine_6", digit: "6", letters: "MNO")
            ],
            leadingInset: 6,
            trailingInset: 6
        )

        let thirdRow = KeyboardRow(
            keys: [
                makeNineKey(identifier: "nine_7", digit: "7", letters: "PQRS"),
                makeNineKey(identifier: "nine_8", digit: "8", letters: "TUV"),
                makeNineKey(identifier: "nine_9", digit: "9", letters: "WXYZ"),
                KeyboardKey(identifier: "delete", title: "⌫", kind: .delete, widthMultiplier: 1.5)
            ],
            leadingInset: 6,
            trailingInset: 6
        )

        let bottomRow = KeyboardRow(
            keys: [
                KeyboardKey(identifier: "modeSwitch", title: "ABC", subtitle: "九宫", kind: .modeSwitch, widthMultiplier: 1.6),
                KeyboardKey(identifier: "emojiToggle", title: "😊", kind: .emojiToggle, widthMultiplier: 1.2),
                KeyboardKey(identifier: "space", title: "空格", kind: .space, widthMultiplier: 4),
                KeyboardKey(identifier: "globe", title: "🌐", kind: .globe, widthMultiplier: 1.2),
                KeyboardKey(identifier: "return", title: "发送", kind: .returnKey, widthMultiplier: 1.6)
            ],
            leadingInset: 6,
            trailingInset: 6
        )

        return [firstRow, secondRow, thirdRow, bottomRow]
    }

    private func makeNineKey(identifier: String, digit: String, letters: String) -> KeyboardKey {
        let alternatives = letters.lowercased().map { String($0) }
        return KeyboardKey(
            identifier: identifier,
            title: letters,
            subtitle: digit,
            output: alternatives.first ?? "",
            kind: .multiCharacter,
            alternatives: alternatives
        )
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
