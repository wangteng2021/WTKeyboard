import UIKit

final class KeyboardViewController: UIInputViewController {
    private let layoutProvider = KeyboardLayoutProvider()
    private let emojiProvider = EmojiProvider()
    
    // 使用本地 rime-ice 词库服务
    private let lexiconService: LocalLexiconService? = {
        #if DEBUG
        print("[Keyboard] Initializing LocalLexiconService...")
        #endif
        let service = LocalLexiconService()
        #if DEBUG
        if service == nil {
            print("[Keyboard] ❌ Failed to initialize LocalLexiconService")
            print("[Keyboard] Troubleshooting:")
            print("  1. Check if SQLite file exists in Bundle or App Group")
            print("  2. Verify App Group configuration in entitlements")
            print("  3. Ensure AppGroupBootstrapper.installSharedLexiconIfNeeded() was called")
        } else {
            print("[Keyboard] ✅ LocalLexiconService initialized successfully")
        }
        #endif
        return service
    }()
    
    // 用户词库缓存（简单的内存缓存）
    private var userLexicon: [String: [String]] = [:]
    private let userLexiconQueue = DispatchQueue(label: "com.wtkeyboard.userlexicon")
    private let appearance = KeyboardAppearance()

    private var keyboardStackView: UIStackView!
    private var candidateCollectionView: UICollectionView!
    private var emojiSegmentedControl: UISegmentedControl!
    private var emojiSegmentHeightConstraint: NSLayoutConstraint?

    private var keyboardMode: KeyboardMode = .fullQwerty {
        didSet {
            if keyboardMode != .emoji {
                previousNonEmojiMode = keyboardMode
            }
            reloadKeyboard()
        }
    }
    private var previousNonEmojiMode: KeyboardMode = .fullQwerty
    private var isUppercaseEnabled = false
    private var emojiCategoryIndex = 0
    private var currentInput: String = "" {
        didSet {
            updateMarkedText()
            updateCandidates()
        }
    }
    private var candidates: [String] = [] {
        didSet {
            candidateCollectionView.reloadData()
        }
    }
    private var multiTapState: MultiTapState?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    override func viewDidLoad() {
        super.viewDidLoad()
        feedbackGenerator.prepare()
        configureViewHierarchy()
        reloadKeyboard()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        multiTapState = nil
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
    }

    private func configureViewHierarchy() {
        view.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.black : UIColor.systemGray6
        }

        configureCandidateCollection()
        configureEmojiSegmentControl()
        configureKeyboardStackView()
    }

    private func configureCandidateCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        candidateCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        candidateCollectionView.translatesAutoresizingMaskIntoConstraints = false
        candidateCollectionView.backgroundColor = .clear
        candidateCollectionView.showsHorizontalScrollIndicator = false
        candidateCollectionView.dataSource = self
        candidateCollectionView.delegate = self
        candidateCollectionView.register(CandidateCell.self, forCellWithReuseIdentifier: CandidateCell.reuseIdentifier)
        view.addSubview(candidateCollectionView)

        NSLayoutConstraint.activate([
            candidateCollectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            candidateCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateCollectionView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureEmojiSegmentControl() {
        let items = emojiProvider.categories.map { $0.shortTitle }
        emojiSegmentedControl = UISegmentedControl(items: items)
        emojiSegmentedControl.selectedSegmentIndex = emojiCategoryIndex
        emojiSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        emojiSegmentedControl.addTarget(self, action: #selector(handleEmojiSegmentChange(_:)), for: .valueChanged)
        emojiSegmentedControl.isHidden = true
        view.addSubview(emojiSegmentedControl)

        emojiSegmentHeightConstraint = emojiSegmentedControl.heightAnchor.constraint(equalToConstant: 0)
        emojiSegmentHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            emojiSegmentedControl.topAnchor.constraint(equalTo: candidateCollectionView.bottomAnchor, constant: 0),
            emojiSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            emojiSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    private func configureKeyboardStackView() {
        keyboardStackView = UIStackView()
        keyboardStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardStackView.axis = .vertical
        keyboardStackView.spacing = 6
        keyboardStackView.distribution = .fillEqually
        view.addSubview(keyboardStackView)

        NSLayoutConstraint.activate([
            keyboardStackView.topAnchor.constraint(equalTo: emojiSegmentedControl.bottomAnchor, constant: 6),
            keyboardStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            keyboardStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            keyboardStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6)
        ])
    }

    private func reloadKeyboard() {
        keyboardStackView.arrangedSubviews.forEach { sub in
            keyboardStackView.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        let isEmojiMode = keyboardMode == .emoji
        emojiSegmentedControl.isHidden = !isEmojiMode
        emojiSegmentHeightConstraint?.constant = isEmojiMode ? 32 : 0

        let emojiSymbols = emojiProvider.symbols(for: emojiCategoryIndex)
        let rows = layoutProvider.layout(for: keyboardMode, uppercase: isUppercaseEnabled, emojiSymbols: emojiSymbols)

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.distribution = .fillProportionally
            rowStack.isLayoutMarginsRelativeArrangement = true
            rowStack.layoutMargins = UIEdgeInsets(top: 0, left: row.leadingInset, bottom: 0, right: row.trailingInset)

            var referenceContainer: UIView?
            var referenceMultiplier: CGFloat = 1

            for key in row.keys {
                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false

                let button = KeyboardButton(key: key, appearance: appearance)
                button.addTarget(self, action: #selector(handleKeyTap(_:)), for: .touchUpInside)
                container.addSubview(button)

                NSLayoutConstraint.activate([
                    button.topAnchor.constraint(equalTo: container.topAnchor),
                    button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                ])

                rowStack.addArrangedSubview(container)

                if let reference = referenceContainer {
                    let ratio = key.widthMultiplier / referenceMultiplier
                    container.widthAnchor.constraint(equalTo: reference.widthAnchor, multiplier: ratio).isActive = true
                } else {
                    referenceContainer = container
                    referenceMultiplier = key.widthMultiplier
                }
            }

            keyboardStackView.addArrangedSubview(rowStack)
        }
    }

    @objc private func handleKeyTap(_ sender: KeyboardButton) {
        feedbackGenerator.impactOccurred()
        let key = sender.key
        switch key.kind {
        case .character:
            handleCharacter(key.output)
        case .multiCharacter:
            handleNineGridKey(key)
        case .delete:
            handleDelete()
        case .space:
            handleSpace()
        case .returnKey:
            handleReturn()
        case .shift:
            isUppercaseEnabled.toggle()
            reloadKeyboard()
        case .modeSwitch:
            toggleKeyboardMode()
        case .emojiToggle:
            toggleEmojiMode()
        case .globe:
            advanceToNextInputMode()
        case .punctuation:
            handlePunctuation(key.output)
        }
    }

    private func handleCharacter(_ value: String) {
        guard !value.isEmpty else { return }
        if keyboardMode == .emoji {
            textDocumentProxy.insertText(value)
            return
        }

        currentInput.append(value.lowercased())
        multiTapState = nil
    }

    private func handleNineGridKey(_ key: KeyboardKey) {
        guard !key.alternatives.isEmpty else { return }
        let now = Date()
        if var state = multiTapState, state.keyID == key.identifier, now.timeIntervalSince(state.timestamp) < 0.7 {
            guard !currentInput.isEmpty else { return }
            currentInput.removeLast()
            state.index = (state.index + 1) % key.alternatives.count
            currentInput.append(key.alternatives[state.index])
            state.timestamp = now
            multiTapState = state
        } else {
            currentInput.append(key.alternatives.first!)
            multiTapState = MultiTapState(keyID: key.identifier, index: 0, timestamp: now)
        }
    }

    private func handleDelete() {
        if !currentInput.isEmpty {
            currentInput.removeLast()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    private func handleSpace() {
        if commitBestCandidate() {
            textDocumentProxy.insertText(" ")
        } else {
            // 如果没有候选词，直接输入空格和原始输入
            if !currentInput.isEmpty {
                textDocumentProxy.insertText(currentInput + " ")
            } else {
                textDocumentProxy.insertText(" ")
            }
        }
        currentInput = ""
    }

    private func handleReturn() {
        if !commitBestCandidate() {
            textDocumentProxy.insertText("\n")
        }
        currentInput = ""
    }

    private func handlePunctuation(_ punctuation: String) {
        guard !punctuation.isEmpty else { return }
        _ = commitBestCandidate()
        textDocumentProxy.insertText(punctuation)
        currentInput = ""
    }

    private func toggleKeyboardMode() {
        if keyboardMode == .fullQwerty {
            keyboardMode = .nineGrid
        } else {
            keyboardMode = .fullQwerty
        }
    }

    private func toggleEmojiMode() {
        if keyboardMode == .emoji {
            keyboardMode = previousNonEmojiMode
        } else {
            previousNonEmojiMode = keyboardMode
            keyboardMode = .emoji
        }
    }

    private func updateCandidates() {
        guard !currentInput.isEmpty else {
            candidates = []
            textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            return
        }
        
        // 使用本地 rime-ice 词库
        let normalized = normalizeInput(currentInput)
        #if DEBUG
        print("[Keyboard] Getting candidates for input: '\(currentInput)' (normalized: '\(normalized)')")
        #endif
        
        var results: [String] = []
        if let service = lexiconService {
            results = service.search(for: normalized, limit: 8)
        }
        
        // 合并用户词库
        var finalCandidates = results
        userLexiconQueue.sync {
            if let userCandidates = userLexicon[normalized], !userCandidates.isEmpty {
                // 将用户词库的候选词放在前面
                finalCandidates = userCandidates + results.filter { !userCandidates.contains($0) }
            }
        }
        
        candidates = Array(finalCandidates.prefix(8))
        #if DEBUG
        print("[Keyboard] Input: '\(currentInput)', Candidates: \(candidates)")
        #endif
    }
    
    private func normalizeInput(_ input: String) -> String {
        return input.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func updateMarkedText() {
        if currentInput.isEmpty {
            textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        } else {
            textDocumentProxy.setMarkedText(currentInput, selectedRange: NSRange(location: currentInput.count, length: 0))
        }
    }

    private func commitCandidate(_ candidate: String, sourceInput: String) {
        guard !candidate.isEmpty else { return }
        textDocumentProxy.insertText(candidate)
        
        // 保存到用户词库
        let normalized = normalizeInput(sourceInput)
        userLexiconQueue.async {
            var bucket = self.userLexicon[normalized] ?? []
            if let existingIndex = bucket.firstIndex(of: candidate) {
                bucket.remove(at: existingIndex)
            }
            bucket.insert(candidate, at: 0)
            self.userLexicon[normalized] = Array(bucket.prefix(10)) // 最多保存10个
        }
        
        currentInput = ""
    }

    private func commitRawInput() {
        guard !currentInput.isEmpty else { return }
        let raw = currentInput
        textDocumentProxy.insertText(raw)
        currentInput = ""
    }

    @discardableResult
    private func commitBestCandidate() -> Bool {
        let source = currentInput
        if let best = candidates.first {
            commitCandidate(best, sourceInput: source)
            return true
        } else if !currentInput.isEmpty {
            commitRawInput()
            return true
        }
        return false
    }

    @objc private func handleEmojiSegmentChange(_ sender: UISegmentedControl) {
        emojiCategoryIndex = sender.selectedSegmentIndex
        reloadKeyboard()
    }
}

private struct MultiTapState {
    let keyID: String
    var index: Int
    var timestamp: Date
}

// MARK: - Collection View

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let base = candidates.count
        return base + (currentInput.isEmpty ? 0 : 1)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CandidateCell.reuseIdentifier, for: indexPath) as? CandidateCell else {
            return UICollectionViewCell()
        }
        let isRawInputCell = !currentInput.isEmpty && indexPath.item == 0
        if isRawInputCell {
            cell.configure(text: currentInput, isPrimary: true)
        } else {
            let index = indexPath.item - (currentInput.isEmpty ? 0 : 1)
            let candidate = candidates[index]
            cell.configure(text: candidate, isPrimary: index == 0 && currentInput.isEmpty)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !currentInput.isEmpty && indexPath.item == 0 {
            commitRawInput()
            return
        }
        let index = indexPath.item - (currentInput.isEmpty ? 0 : 1)
        guard candidates.indices.contains(index) else { return }
        commitCandidate(candidates[index], sourceInput: currentInput)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text: String
        if !currentInput.isEmpty && indexPath.item == 0 {
            text = currentInput
        } else {
            let index = indexPath.item - (currentInput.isEmpty ? 0 : 1)
            text = candidates.indices.contains(index) ? candidates[index] : ""
        }
        let width = CandidateCell.width(for: text)
        return CGSize(width: width, height: 36)
    }
}

final class CandidateCell: UICollectionViewCell {
    static let reuseIdentifier = "CandidateCell"
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor.secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.systemGray4.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String, isPrimary: Bool) {
        label.text = text
        contentView.backgroundColor = isPrimary ? UIColor.systemBlue.withAlphaComponent(0.15) : UIColor.secondarySystemBackground
    }

    static func width(for text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return max(44, size.width + 24)
    }
}
