import Foundation

enum AppGroup {
    // 注意：必须与 entitlements 文件中的 App Group 标识符一致
    static let identifier = "group.com.ddm.account"

    static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func fileURL(appending relativePath: String) -> URL? {
        containerURL()?.appendingPathComponent(relativePath)
    }

    enum Resource {
        static let lexicon = "Lexicon/rime_lexicon.json"
        static let sqliteLexicon = "Lexicon/rime_lexicon.sqlite"
        static let userPhrases = "Lexicon/user_phrases.json"
    }
}
