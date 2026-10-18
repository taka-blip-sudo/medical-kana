import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: HomeViewController())
        window.makeKeyAndVisible(); self.window = window
        return true
    }
}

final class HomeViewController: UIViewController, UISearchBarDelegate {
    private let store = DictionaryStore()
    private let results = UITextView()
    private let practical = UISwitch()
    private var searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "医療かな・試作版"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "出典", style: .plain, target: self, action: #selector(licenses))
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
        let guide = UILabel(); guide.numberOfLines = 0; guide.font = .systemFont(ofSize: 16)
        guide.text = "設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加 → 医療かな\n\n入力欄の地球儀で切り替えます。フルアクセスは不要です。まずメモアプリで試してください。医療用語の候補選択に特化した試作版です。"
        stack.addArrangedSubview(guide)
        let notice = UILabel(); notice.numberOfLines = 0; notice.font = .systemFont(ofSize: 13)
        notice.textColor = .secondaryLabel
        notice.text = "一般文の自動変換・学習は未対応です。パスワード欄などでは標準キーボードになります。病院のシステムでは利用を制限される場合があります。"
        stack.addArrangedSubview(notice)
        searchBar.placeholder = "読みを入力して辞書を試す（例：ちるぜぱちど）"
        searchBar.delegate = self; stack.addArrangedSubview(searchBar)
        let row = UIStackView(); row.spacing = 8
        let label = UILabel(); label.text = "実践用語も検索"; row.addArrangedSubview(label); row.addArrangedSubview(practical)
        practical.addTarget(self, action: #selector(search), for: .valueChanged)
        stack.addArrangedSubview(row)
        results.isEditable = false; results.font = .systemFont(ofSize: 17)
        results.text = store.error ?? "ここで辞書の候補を確認できます。\nキーボードでの実践用語ON/OFFはキーボード内で切り替えます。"
        stack.addArrangedSubview(results)
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { search() }
    @objc private func search() {
        let items = store.candidates(for: searchBar.text ?? "", includePractical: practical.isOn)
        results.text = store.error ?? items.map { $0.word + "（" + $0.reading + "）" }.joined(separator: "\n")
    }
    @objc private func licenses() {
        let controller = UIViewController(); controller.title = "出典と利用条件"
        let text = UITextView(); text.isEditable = false; text.font = .systemFont(ofSize: 14)
        let names = ["NOTICE", "GPL-2.0", "CC-BY-4.0"]
        text.text = names.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n────────\n\n")
        controller.view = text
        navigationController?.pushViewController(controller, animated: true)
    }
}
