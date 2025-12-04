import Foundation

struct EmojiCategory {
    let title: String
    let shortTitle: String
    let symbols: [String]
}

final class EmojiProvider {
    let categories: [EmojiCategory]

    init() {
        categories = [
            EmojiCategory(title: "常用", shortTitle: "常用", symbols: [
                "😀", "😄", "😁", "😊", "😇", "🙂", "🙃", "😉",
                "😍", "😘", "😗", "😚", "😋", "😜", "🤪", "🤩",
                "🤗", "🤔", "🤨", "😐", "😶", "😏", "🙄", "😬",
                "😭", "😡", "🤯", "🥳", "🤠", "🥹", "🥰", "🤤"
            ]),
            EmojiCategory(title: "手势", shortTitle: "手势", symbols: [
                "👍", "👎", "👌", "🤌", "🤙", "👏", "🙌", "👐",
                "🤲", "🙏", "💪", "🫶", "🤝", "✌️", "🤘", "🤟",
                "👊", "🖐️", "✋", "🤚", "☝️", "👇", "👆", "👉"
            ]),
            EmojiCategory(title: "自然", shortTitle: "自然", symbols: [
                "🌞", "🌝", "⭐️", "⚡️", "🔥", "💧", "🌊", "🌈",
                "🍀", "🌸", "🌻", "🌹", "🌵", "🌳", "🌲", "🍁",
                "🍂", "☃️", "❄️", "⛄️", "🌪️", "🌤️", "🌀", "🌙"
            ])
        ]
    }

    func symbols(for index: Int) -> [String] {
        guard categories.indices.contains(index) else { return categories.first?.symbols ?? [] }
        return categories[index].symbols
    }
}
