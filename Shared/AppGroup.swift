import Foundation

enum AppGroup {
    static let identifier = "group.com.ddm.similar"

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
        static let userPhrases = "Lexicon/user_phrases.json"
    }
}
