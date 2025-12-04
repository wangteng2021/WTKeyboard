import UIKit

struct KeyboardAppearance {
    let keyBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor.secondarySystemBackground : UIColor.white
    }
    let keyForeground = UIColor.label
    let highlightedBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor.systemGray3 : UIColor.systemGray4
    }
    let borderColor = UIColor.systemGray4.cgColor
}

final class KeyboardButton: UIButton {
    let key: KeyboardKey
    private let appearance: KeyboardAppearance

    init(key: KeyboardKey, appearance: KeyboardAppearance) {
        self.key = key
        self.appearance = appearance
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = 8
        layer.borderWidth = 0.5
        layer.borderColor = appearance.borderColor
        backgroundColor = appearance.keyBackground
        clipsToBounds = true

        setTitle(key.title, for: .normal)
        setTitleColor(appearance.keyForeground, for: .normal)
        titleLabel?.font = font(for: key)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
        titleLabel?.numberOfLines = key.kind == .multiCharacter ? 2 : 1
        titleLabel?.textAlignment = .center
        contentEdgeInsets = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)

        if let subtitle = key.subtitle {
            let attributed = NSMutableAttributedString(string: "\(key.title)\n", attributes: [
                .font: font(for: key),
                .foregroundColor: appearance.keyForeground
            ])
            attributed.append(NSAttributedString(string: subtitle, attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]))
            setAttributedTitle(attributed, for: .normal)
            titleLabel?.numberOfLines = 2
        }

        accessibilityLabel = key.title
    }

    private func font(for key: KeyboardKey) -> UIFont {
        switch key.kind {
        case .character, .punctuation:
            return UIFont.systemFont(ofSize: 20, weight: .medium)
        case .multiCharacter:
            return UIFont.systemFont(ofSize: 16, weight: .semibold)
        default:
            return UIFont.systemFont(ofSize: 16, weight: .semibold)
        }
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? appearance.highlightedBackground : appearance.keyBackground
        }
    }
}
