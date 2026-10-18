import UIKit

final class KanaKey: UIControl {
    private let kana: [String]
    private let label = UILabel()
    private var origin = CGPoint.zero
    var onKanaSelected: ((String) -> Void)?

    init(_ kana: [String]) {
        self.kana = kana
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 7
        label.numberOfLines = 2
        label.textAlignment = .center
        label.text = kana[0] + "\n" + kana.dropFirst().joined(separator: " ")
        label.font = .systemFont(ofSize: 17)
        label.isUserInteractionEnabled = false
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityLabel = kana.joined(separator: "、")
        accessibilityHint = "タップで先頭、左・上・右・下にフリックで続く文字"
        accessibilityTraits = .keyboardKey
        accessibilityCustomActions = kana.map { value in
            UIAccessibilityCustomAction(name: value) { [weak self] _ in self?.onKanaSelected?(value); return true }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        origin = touch.location(in: self); alpha = 0.65; return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        alpha = 1
        guard let touch else { return }
        let point = touch.location(in: self)
        let dx = point.x - origin.x, dy = point.y - origin.y
        let index: Int
        if max(abs(dx), abs(dy)) < 14 { index = 0 }
        else if abs(dx) > abs(dy) { index = dx < 0 ? 1 : 3 }
        else { index = dy < 0 ? 2 : 4 }
        if kana.indices.contains(index) { onKanaSelected?(kana[index]) }
    }
    override func cancelTracking(with event: UIEvent?) { alpha = 1 }
}
