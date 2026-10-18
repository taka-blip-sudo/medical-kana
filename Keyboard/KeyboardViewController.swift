import UIKit

final class KeyboardViewController: UIInputViewController {
    private let store = DictionaryStore()
    private let composition = UILabel()
    private let candidateStack = UIStackView()
    private var reading = ""
    private var includePractical = false
    private var alphabetMode = false
    private let layout = UIStackView()
    private var searchWork: DispatchWorkItem?
    private let searchQueue = DispatchQueue(label: "org.medkey.search", qos: .userInitiated)
    private var generation = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        includePractical = UserDefaults.standard.bool(forKey: "includePractical")
        view.backgroundColor = .systemGroupedBackground
        layout.axis = .vertical; layout.spacing = 5
        layout.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            layout.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            layout.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            layout.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 340)
        height.priority = .defaultHigh; height.isActive = true
        rebuild()
    }

    private func action(_ title: String, _ callback: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 7
        button.addAction(UIAction { _ in callback() }, for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        return button
    }

    private func row(_ views: [UIView]) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.distribution = .fillEqually; stack.spacing = 5
        layout.addArrangedSubview(stack)
    }

    private func rebuild() {
        for child in layout.arrangedSubviews { layout.removeArrangedSubview(child); child.removeFromSuperview() }
        composition.textColor = .label
        composition.font = .systemFont(ofSize: 16)
        composition.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        layout.addArrangedSubview(composition)
        let scroll = UIScrollView()
        scroll.heightAnchor.constraint(equalToConstant: 48).isActive = true
        candidateStack.axis = .horizontal; candidateStack.spacing = 6
        candidateStack.removeFromSuperview()
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(candidateStack)
        NSLayoutConstraint.activate([
            candidateStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            candidateStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        layout.addArrangedSubview(scroll)
        if alphabetMode {
            for letters in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
                row(letters.map { c in action(String(c)) { [weak self] in self?.literal(String(c)) } })
            }
        } else {
            for groups in [
                [["あ","い","う","え","お"],["か","き","く","け","こ"],["さ","し","す","せ","そ"]],
                [["た","ち","つ","て","と"],["な","に","ぬ","ね","の"],["は","ひ","ふ","へ","ほ"]],
                [["ま","み","む","め","も"],["や","（","ゆ","）","よ"],["ら","り","る","れ","ろ"]]
            ] {
                row(groups.map { values in
                    let key = KanaKey(values)
                    key.selected = { [weak self] value in self?.append(value) }
                    return key
                })
            }
        }
        let wa = KanaKey(["わ","を","ん","ー","〜"])
        wa.selected = { [weak self] in self?.append($0) }
        row([
            action("゛゜小") { [weak self] in self?.modifyLast() },
            wa,
            action("⌫") { [weak self] in self?.backspace() }
        ])
        row([
            action("🌐") { [weak self] in self?.commitReading(); self?.advanceToNextInputMode() },
            action(alphabetMode ? "かな" : "ABC") { [weak self] in
                guard let self else { return }; self.commitReading(); self.alphabetMode.toggle(); self.rebuild()
            },
            action("空白") { [weak self] in
                guard let self else { return }
                if self.reading.isEmpty { self.textDocumentProxy.insertText(" ") } else { self.commitReading() }
            },
            action("確定 ↵") { [weak self] in
                guard let self else { return }
                if self.reading.isEmpty { self.textDocumentProxy.insertText("\n") } else { self.commitReading() }
            },
            action(includePractical ? "実践ON" : "実践OFF") { [weak self] in
                guard let self else { return }
                self.includePractical.toggle()
                UserDefaults.standard.set(self.includePractical, forKey: "includePractical")
                self.rebuild()
            }
        ])
        refresh()
    }

    private func append(_ value: String) {
        guard reading.count < 100 else { return }
        reading += value; refresh()
    }
    private func literal(_ value: String) { commitReading(); textDocumentProxy.insertText(value) }
    private func backspace() {
        if reading.isEmpty { textDocumentProxy.deleteBackward() }
        else { reading.removeLast(); refresh() }
    }
    private func modifyLast() {
        guard let last = reading.last else { return }
        let cycles = ["かが","きぎ","くぐ","けげ","こご","さざ","しじ","すず","せぜ","そぞ","ただ","ちぢ","つづっ","てで","とど","はばぱ","ひびぴ","ふぶぷ","へべぺ","ほぼぽ","うゔぅ","あぁ","いぃ","えぇ","おぉ","やゃ","ゆゅ","よょ","わゎ"]
        for cycle in cycles {
            let letters = Array(cycle)
            if let i = letters.firstIndex(of: last) {
                reading.removeLast(); reading.append(letters[(i + 1) % letters.count]); refresh(); return
            }
        }
    }
    private func commitReading() {
        guard !reading.isEmpty else { return }
        textDocumentProxy.insertText(reading); reading = ""; refresh()
    }
    private func choose(_ word: String) {
        textDocumentProxy.insertText(word); reading = ""; refresh()
    }
    private func show(_ candidates: [MedicalCandidate]) {
        for child in candidateStack.arrangedSubviews { candidateStack.removeArrangedSubview(child); child.removeFromSuperview() }
        for item in candidates {
            let button = action("  " + item.word + "  ") { [weak self] in self?.choose(item.word) }
            button.accessibilityLabel = item.word + "、よみ、" + item.reading
            candidateStack.addArrangedSubview(button)
        }
    }
    private func refresh() {
        generation += 1
        let version = generation, query = reading, practical = includePractical
        composition.text = store.error ?? (query.isEmpty ? "医療かな：フリック入力 → 候補をタップ" : query)
        searchWork?.cancel(); show([])
        guard !query.isEmpty else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let results = self.store.candidates(for: query, includePractical: practical)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == version else { return }
                self.show(results)
            }
        }
        searchWork = work
        searchQueue.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
