import XCTest
import UIKit

final class KeyboardTests: XCTestCase {
    func testEverydayAndMedicalConversion() {
        let engine = JapaneseConversion()
        let cases: [(String, String)] = [("きょう", "今日"), ("あした", "明日"), ("とうきょう", "東京"),
                                          ("しんきんこうそく", "心筋梗塞"), ("とうにょうびょう", "糖尿病")]
        for (reading, word) in cases {
            let results = engine.candidates(for: reading)
            XCTAssertTrue(results.contains(word), "\(reading): \(results)")
            XCTAssertEqual(Set(results).count, results.count)
            engine.complete(word)
        }
        let sentence = engine.candidates(for: "きょうはいいてんきです")
        XCTAssertTrue(sentence.contains { $0.contains("今日") && $0.contains("天気") }, "\(sentence)")
        engine.complete(nil)
        XCTAssertTrue(engine.candidates(for: "しんきん").contains("心筋梗塞"))
        XCTAssertTrue(engine.candidates(for: "").isEmpty)
    }

    @MainActor func testKanaLayoutAndCandidateSelection() throws {
        let controller = KeyboardViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 310))
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        var all = descendants(controller.view)
        let kana = all.compactMap { $0 as? KanaKey }
        XCTAssertEqual(kana.count, 11)
        func key(_ label: String) throws -> KanaKey {
            try XCTUnwrap(kana.first { $0.accessibilityLabel?.hasPrefix(label) == true })
        }
        let a = try key("あ、"), ka = try key("か、"), sa = try key("さ、"), ta = try key("た、"), wa = try key("わ、")
        XCTAssertLessThan(a.convert(a.bounds, to: window).midX, ka.convert(ka.bounds, to: window).midX)
        XCTAssertLessThan(ka.convert(ka.bounds, to: window).midX, sa.convert(sa.bounds, to: window).midX)
        XCTAssertLessThan(a.convert(a.bounds, to: window).midY, ta.convert(ta.bounds, to: window).midY)
        XCTAssertGreaterThan(wa.convert(wa.bounds, to: window).midY, ta.convert(ta.bounds, to: window).midY)
        for k in kana { XCTAssertGreaterThanOrEqual(k.bounds.height, 44); XCTAssertGreaterThanOrEqual(k.bounds.width, 44) }
        a.onKanaSelected?("あ")
        all = descendants(controller.view)
        XCTAssertEqual((all.first { $0.accessibilityIdentifier == "composition" } as? UILabel)?.text, "あ")
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) })
        attachment.name = "Japanese-kana-layout"; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true
    }
}
