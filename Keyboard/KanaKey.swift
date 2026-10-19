import UIKit

final class KanaKey: UIControl {
    private let kana: [String]
    private let label = UILabel()
    private var origin = CGPoint.zero
    private var balloon: UIView?
    private var choices: [UILabel] = []
    var onKanaSelected: ((String) -> Void)?
    init(_ kana: [String]) {
        self.kana = kana; super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground; layer.cornerRadius = 6
        label.textAlignment = .center; label.text = kana[0]; label.font = .systemFont(ofSize: 28)
        label.isUserInteractionEnabled = false; addSubview(label); label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: leadingAnchor), label.trailingAnchor.constraint(equalTo: trailingAnchor),
                                     label.topAnchor.constraint(equalTo: topAnchor), label.bottomAnchor.constraint(equalTo: bottomAnchor)])
        isAccessibilityElement = true; accessibilityLabel = kana.joined(separator: "、"); accessibilityTraits = .keyboardKey
        accessibilityHint = "タップ、または左・上・右・下にフリック"
        accessibilityCustomActions = kana.map { value in
            UIAccessibilityCustomAction(name: value) { [weak self] _ in self?.onKanaSelected?(value); return true }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func index(at point: CGPoint) -> Int {
        let dx = point.x-origin.x, dy = point.y-origin.y
        if max(abs(dx),abs(dy)) < 12 { return 0 }
        if abs(dx) > abs(dy) { return dx < 0 ? 1 : 3 }; return dy < 0 ? 2 : 4
    }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        origin = touch.location(in: self); backgroundColor = .systemGray3
        var root: UIView = self
        while let parent = root.superview, !(parent is UIInputView) { root = parent }
        let box = UIView(frame: CGRect(x: 0, y: 0, width: 126, height: 138)); box.isUserInteractionEnabled = false
        box.layer.cornerRadius = 12; box.backgroundColor = .secondarySystemBackground
        box.layer.shadowOpacity = 0.2; box.layer.shadowRadius = 4
        let center = convert(CGPoint(x: bounds.midX,y: bounds.midY),to: root)
        box.center = CGPoint(x: min(max(center.x,64),root.bounds.width-64),y: min(max(center.y-24,70),root.bounds.height-70))
        let points = [CGPoint(x:42,y:46),CGPoint(x:0,y:46),CGPoint(x:42,y:0),CGPoint(x:84,y:46),CGPoint(x:42,y:92)]
        choices = kana.enumerated().map { i,value in
            let item = UILabel(frame: CGRect(origin: points[i],size: CGSize(width:42,height:46)))
            item.text = value; item.textAlignment = .center; item.font = .systemFont(ofSize:25)
            item.layer.cornerRadius = 7; item.clipsToBounds = true; box.addSubview(item); return item
        }; root.addSubview(box); balloon = box; highlight(0); return true
    }
    private func highlight(_ index: Int) {
        for (i,item) in choices.enumerated() { item.backgroundColor = i == index ? .systemBlue : .clear; item.textColor = i == index ? .white : .label }
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { highlight(index(at:touch.location(in:self))); return true }
    private func dismiss() { backgroundColor = .secondarySystemBackground; balloon?.removeFromSuperview(); balloon = nil; choices = [] }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let selectedIndex = touch.map { index(at:$0.location(in:self)) } ?? 0; dismiss()
        if kana.indices.contains(selectedIndex) { onKanaSelected?(kana[selectedIndex]) }
    }
    override func cancelTracking(with event: UIEvent?) { dismiss() }
}
