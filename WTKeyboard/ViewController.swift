//
//  ViewController.swift
//  WTKeyboard
//
//  Created by wt on 2025/12/4.
//

import UIKit

final class ViewController: UIViewController {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let stepStackView = UIStackView()
    private let settingsButton = UIButton(type: .system)
    private let rimeTipLabel = UILabel()

    private let steps: [String] = [
        "进入 设置 > 通用 > 键盘 > 键盘 > 添加新键盘，选择“WT九宫输入法”。",
        "回到键盘列表，点选“WT九宫输入法”并开启“允许完全访问”，以便加载 Rime 词库和用户词记忆。",
        "在任意输入框长按 🌐，即可切换至 WT 键盘。通过左下角切换 9 键 / 26 键布局，右下角进入表情页面。"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        populateSteps()
    }

    private func configureLayout() {
        titleLabel.text = "WT Rime 键盘"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)

        descriptionLabel.text = "一个支持 9 键与 26 键、并内置 Rime 大词库的自定义输入法扩展。"
        descriptionLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.numberOfLines = 0

        stepStackView.axis = .vertical
        stepStackView.spacing = 12

        settingsButton.setTitle("打开系统键盘设置", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        rimeTipLabel.text = "提示：在工程的 WTRimeKeyboard/Resources 目录放入 Rime 词库（JSON/YAML），重新编译即可把大词库随键盘分发。"
        rimeTipLabel.numberOfLines = 0
        rimeTipLabel.font = UIFont.systemFont(ofSize: 15)
        rimeTipLabel.textColor = .secondaryLabel

        let container = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, stepStackView, settingsButton, rimeTipLabel])
        container.axis = .vertical
        container.spacing = 20
        container.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32)
        ])
    }

    private func populateSteps() {
        steps.enumerated().forEach { index, text in
            let label = UILabel()
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 16)
            label.text = "\(index + 1). \(text)"
            stepStackView.addArrangedSubview(label)
        }
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

