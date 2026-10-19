import UIKit
import KanaKanjiConverterModule
import KanaKanjiConverterModuleWithDefaultDictionary

// Accessed only on the serial conversion queue; all conversion is offline.
final class JapaneseConversion {
    private let converter = KanaKanjiConverter.withDefaultDictionary()
    private let medical = DictionaryStore()
    private var byText: [String: Candidate] = [:]
    private let options: ConvertRequestOptions = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MedKeyLearning")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return .init(N_best: 8, requireJapanesePrediction: true, requireEnglishPrediction: false,
                     keyboardLanguage: .ja_JP, learningType: .inputAndOutput, maxMemoryCount: 2048,
                     memoryDirectoryURL: dir, sharedContainerURL: dir, textReplacer: .empty,
                     specialCandidateProviders: nil, metadata: .init(versionString: "MedKey 0.2.0"))
    }()
    func candidates(for reading: String) -> [String] {
        guard !reading.isEmpty else { return [] }
        var text = ComposingText(); text.insertAtCursorPosition(reading, inputStyle: .direct)
        // mainResults also contains first-clause-only entries. This UI commits
        // the whole reading, so omit partial entries rather than dropping its tail.
        let ordinary = converter.requestCandidates(text, options: options).mainResults.filter { $0.rubyCount >= reading.count }
        byText.removeAll(keepingCapacity: true)
        for item in ordinary where byText[item.text] == nil { byText[item.text] = item }
        let terms = medical.candidates(for: reading, includePractical: false, limit: 24)
        let exact = terms.filter { $0.reading == reading }.map(\.word)
        let prefix = terms.filter { $0.reading != reading }.map(\.word)
        var merged = Array(ordinary.prefix(3)).map(\.text)
        merged.insert(contentsOf: exact.prefix(3), at: min(1, merged.count))
        merged += Array(ordinary.dropFirst(3)).map(\.text)
        merged += Array(exact.dropFirst(3)) + prefix
        merged += [reading, reading.applyingTransform(.hiraganaToKatakana, reverse: false) ?? reading]
        var seen = Set<String>()
        return merged.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    func complete(_ word: String?) {
        if let word, let candidate = byText[word] {
            converter.updateLearningData(candidate); converter.commitUpdateLearningData()
        }
        converter.stopComposition(); byText.removeAll(keepingCapacity: true)
    }
}

final class KeyboardViewController: UIInputViewController {
    private let layout = UIStackView(), candidates = UIStackView(), keys = UIStackView()
    private let composition = UILabel(), candidateScroll = UIScrollView()
    private let queue = DispatchQueue(label: "org.medkey.conversion", qos: .userInitiated)
    private var engine: JapaneseConversion? // confined to queue
    private var pending: DispatchWorkItem?
    private var generation = 0, mode = 0
    private var reading = "", lastWord = "", lastReading = ""
    private var words: [String] = []
    private var expanded = false
    private var deleteTimer: Timer?
    private var renderedMode = -1
    private var renderedExpanded = false
    private var returnButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemGray4
        layout.axis = .vertical; layout.spacing = 5; layout.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            layout.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            layout.topAnchor.constraint(equalTo: view.topAnchor, constant: 3),
            layout.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)])
        let height = view.heightAnchor.constraint(equalToConstant: 310); height.priority = .defaultHigh; height.isActive = true
        composition.font = .systemFont(ofSize: 16); composition.accessibilityIdentifier = "composition"
        composition.heightAnchor.constraint(equalToConstant: 23).isActive = true; layout.addArrangedSubview(composition)
        let bar = UIStackView(); bar.spacing = 3
        candidates.axis = .horizontal; candidates.spacing = 2; candidates.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidates); candidateScroll.showsHorizontalScrollIndicator = false
        NSLayoutConstraint.activate([
            candidates.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidates.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidates.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidates.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidates.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor)])
        bar.addArrangedSubview(candidateScroll)
        let more = button("⌄") { [weak self] in guard let self else { return }; self.expanded.toggle(); self.render() }
        more.accessibilityLabel = "変換候補を一覧表示"; more.widthAnchor.constraint(equalToConstant: 38).isActive = true
        bar.addArrangedSubview(more); bar.heightAnchor.constraint(equalToConstant: 43).isActive = true; layout.addArrangedSubview(bar)
        keys.axis = .horizontal; keys.spacing = 5; keys.distribution = .fillEqually; layout.addArrangedSubview(keys)
        refresh()
    }
    private func button(_ title: String, _ callback: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17); b.backgroundColor = .systemGray3; b.layer.cornerRadius = 6
        b.addAction(UIAction { _ in callback() }, for: .touchUpInside); return b
    }
    private func clear(_ stack: UIStackView) {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
    }
    private func column(_ items: [UIView]) {
        let s = UIStackView(arrangedSubviews: items); s.axis = .vertical; s.spacing = 7; s.distribution = .fillEqually
        keys.addArrangedSubview(s)
    }
    private func kana(_ values: String) -> KanaKey {
        let k = KanaKey(values.map(String.init)); k.onKanaSelected = { [weak self] value in
            guard let self else { return }
            if self.mode == 0 { if self.reading.count < 80 { self.reading += value; self.expanded = false; self.refresh() } }
            else { self.commit(); self.textDocumentProxy.insertText(value) }
        }; return k
    }
    private func switchMode(_ value: Int) { commit(); mode = mode == value ? 0 : value; expanded = false; render() }
    private func render() {
        clear(candidates); candidateScroll.setContentOffset(.zero, animated: false)
        for word in words {
            let b = button("  " + word + "  ") { [weak self] in self?.choose(word) }; b.backgroundColor = .clear
            b.accessibilityLabel = word; b.accessibilityIdentifier = "candidate-" + word; candidates.addArrangedSubview(b)
        }
        returnButton?.setTitle(reading.isEmpty ? "改行" : "確定", for: .normal)
        if !expanded && !renderedExpanded && renderedMode == mode && !keys.arrangedSubviews.isEmpty { return }
        renderedMode = mode; renderedExpanded = expanded
        clear(keys)
        if expanded {
            let scroll = UIScrollView(), list = UIStackView(); list.axis = .vertical; list.spacing = 3
            list.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(list)
            NSLayoutConstraint.activate([
                list.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                list.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                list.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
            for word in words {
                let b = button(word) { [weak self] in self?.choose(word) }; b.heightAnchor.constraint(equalToConstant: 42).isActive = true
                list.addArrangedSubview(b)
            }; keys.addArrangedSubview(scroll); return
        }
        let globe = button("🌐") {}; globe.accessibilityLabel = "次のキーボード"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        column([button("↶") { [weak self] in self?.undo() }, button(mode == 1 ? "かな" : "ABC") { [weak self] in self?.switchMode(1) },
                button(mode == 2 ? "かな" : "123") { [weak self] in self?.switchMode(2) }, globe])
        if mode == 0 {
            column([kana("あいうえお"), kana("たちつてと"), kana("まみむめも"), button("小゛゜") { [weak self] in self?.modify() }])
            column([kana("かきくけこ"), kana("なにぬねの"), kana("や（ゆ）よ"), kana("わをんー〜")])
            column([kana("さしすせそ"), kana("はひふへほ"), kana("らりるれろ"), kana("、。？！・")])
        } else if mode == 1 {
            column([kana("@/:~_"), kana("ghiGH"), kana("pqrsP"), kana("-+=_#")])
            column([kana("abcAB"), kana("jklJK"), kana("tuvTU"), kana("'\"()&")])
            column([kana("defDE"), kana("mnoMN"), kana("wxyzW"), kana(".,?!;")])
        } else {
            column([kana("1☆♪→←"), kana("4○×□△"), kana("7〒々〆※"), kana("()[]{")])
            column([kana("2¥$€£"), kana("5+-×÷"), kana("8<>=≠"), kana("0〜…%‰")])
            column([kana("3%℃°#"), kana("6&@/\\"), kana("9^_|~"), kana(".,?!:")])
        }
        let del = button("⌫") { [weak self] in self?.backspace() }; del.accessibilityLabel = "削除"
        del.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(repeatDelete(_:))))
        let enter = button(reading.isEmpty ? "改行" : "確定") { [weak self] in guard let self else { return }
            if self.reading.isEmpty { self.textDocumentProxy.insertText("\n") } else { self.commit() }
        }
        returnButton = enter
        let space = button("空白") { [weak self] in guard let self else { return }
            if self.reading.isEmpty { self.textDocumentProxy.insertText(" ") } else { self.choose(self.words.first ?? self.reading) }
        }
        let right = UIStackView(arrangedSubviews: [del, space, enter]); right.axis = .vertical; right.spacing = 7
        del.heightAnchor.constraint(equalTo: space.heightAnchor).isActive = true
        enter.heightAnchor.constraint(equalTo: del.heightAnchor, multiplier: 2, constant: 7).isActive = true
        keys.addArrangedSubview(right)
    }
    private func backspace() {
        lastWord = ""
        if reading.isEmpty { textDocumentProxy.deleteBackward() } else { reading.removeLast(); refresh() }
    }
    @objc private func repeatDelete(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            backspace(); deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in self?.backspace() }
        } else if recognizer.state != .changed { deleteTimer?.invalidate(); deleteTimer = nil }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); deleteTimer?.invalidate(); deleteTimer = nil
    }
    private func modify() {
        guard let last = reading.last else { return }
        for cycle in ["かが","きぎ","くぐ","けげ","こご","さざ","しじ","すず","せぜ","そぞ","ただ","ちぢ","つづっ","てで","とど","はばぱ","ひびぴ","ふぶぷ","へべぺ","ほぼぽ","うゔぅ","あぁ","いぃ","えぇ","おぉ","やゃ","ゆゅ","よょ","わゎ"] {
            let chars = Array(cycle)
            if let i = chars.firstIndex(of: last) { reading.removeLast(); reading.append(chars[(i+1) % chars.count]); refresh(); return }
        }
    }
    private func commit() { if !reading.isEmpty { choose(reading) } }
    private func choose(_ word: String) {
        lastReading = reading; lastWord = word; textDocumentProxy.insertText(word); reading = ""; expanded = false
        queue.async { [weak self] in self?.engine?.complete(word) }; refresh()
    }
    private func undo() {
        guard reading.isEmpty, !lastWord.isEmpty, textDocumentProxy.documentContextBeforeInput?.hasSuffix(lastWord) == true else { return }
        for _ in lastWord { textDocumentProxy.deleteBackward() }; reading = lastReading; lastWord = ""; refresh()
    }
    private func refresh() {
        generation += 1; let version = generation, query = reading
        composition.text = query; pending?.cancel(); words = []; render()
        guard !query.isEmpty else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }; if self.engine == nil { self.engine = JapaneseConversion() }
            let result = self.engine!.candidates(for: query)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == version else { return }; self.words = result; self.render()
            }
        }; pending = work; queue.asyncAfter(deadline: .now() + 0.07, execute: work)
    }
}
