# 医療かな — 無料のiPhone医療キーボード試作プロジェクト

**状態：ソースと辞書を作成済み。iOSビルド・署名・実機確認は未実施です。これは、そのままiPhoneへインストールできるIPAではありません。**

有料ATOKを必要としない、辞書を内蔵した独立した日本語キーボードです。iPhone標準キーボードを変更するものではありません。

## 現在実装したもの

- かなフリック入力：中央をタップ、左・上・右・下へフリック。例：か・き・く・け・こ。
- 濁点・半濁点・小書きへの切り替え。入力直後に「゛゜小」を押します。
- 読みの完全一致候補を先に表示し、前方一致候補も表示。候補をタップして入力欄へ挿入。
- 基本78,956件、任意の実践用語79,845件、合計158,801件。Unicodeを使えるため、ATOK向けShift-JIS版より多くの語を扱えます。
- 「実践OFF/ON」で看護・処置・検査等を含む候補を切り替え。初期設定はOFF。
- 英小文字、削除、空白、読みの確定、改行、別キーボードへの切り替え。
- アプリ本体に辞書の試し検索と出典表示。
- iPhone内のSQLiteファイルだけで辞書検索。フルアクセス・ネットワーク通信・広告・課金・入力履歴の収集は実装していません。

「一般文の自動かな漢字変換」「文脈による選択」「入力学習」は実装していません。医学用語の候補選択に特化した試作です。英大文字・数字・一般記号は地球儀から標準キーボードに切り替えて入力してください。入力中の読みは、確定前はキーボード内に表示され、確定後に入力先へ挿入されます。

iOSのパスワード・一部電話番号入力欄や、外部キーボードを許可しないアプリでは使えません。病院端末の利用可否は施設側の設定・運用に依存します。

## 無料でiPhoneへ導入する経路

必要なもの：Windows PC、iPhone（プロジェクトの対象はiOS 16以降）、無料GitHubアカウント、Apple Account、USB接続等。

1. https://github.com/signup で無料のGitHubアカウントを作成します。メール認証等は本人が行います。
2. 公開リポジトリを新規作成し、このフォルダの中身をアップロードします。リポジトリ直下がproject.yml、App、Keyboard、Shared、Resources、.githubとなるようにします。ZIPそのものを置くのではなく解凍した中身を置きます。「OriginalSources」と「DictionarySources」も権利表示・編集可能な原典として含めます。公開するとソースと辞書も公開されます。個人の医療記録・アカウント情報を追加しないでください。現在の配布物に患者記録・ログイン情報は含めていません。
3. GitHubの「Actions」→「Build iPhone prototype」→「Run workflow」を実行します。標準のMac実行環境でビルドします。ワークフローは手動実行のみです。公開リポジトリの標準GitHubホストランナーは公式案内上無料です。非公開の場合は無料枠・課金設定が別にあります。
4. 成功後、Artifactsの「MedKey-unsigned-IPA」を取得し、ZIP内のMedKey-unsigned.ipaを取り出します。これは未署名ファイルなので、iPhoneへ直接タップして入れることはできません。
5. AltStore Classic / AltServerの公式Windows手順に従って個人用に署名し、IPAを導入します。キーボード拡張はアプリの一部なので保持してください。Appleのログインは本人が公式ソフト上で行い、認証情報をGitHubやこのプロジェクトへ入力しません。このIPAと拡張が現行AltStoreで正常に再署名・起動できるかは未検証です。
6. iPhoneの「設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加」で「医療かな」を追加します。入力欄で地球儀から切り替えます。フルアクセスの許可は不要です。

無料アカウントによるAltStore導入は、通常7日で有効期限が来るため更新が必要です。Appleの開発者モード・端末の信頼設定なども公式手順に従います。無料署名にはApp IDや同時利用アプリ数の制約があり、キーボード拡張もApp IDを使用します。App Storeの通常配布や、更新不要の無料インストールを実現したという意味ではありません。

これらのアカウント作成・外部公開・ビルド実行・端末導入は、今回まだ行っていません。まず無料アカウントを作成し、ビルド結果の確認を進める必要があります。ビルドが失敗した場合はエラーログをもとに修正します。

## Macで開発する場合

HomebrewからXcodeGenを導入し、このフォルダで`xcodegen generate`を実行してMedKey.xcodeprojを開きます。アプリ・拡張の署名Teamを自分のApple Accountへ設定します。Bundle IDを変更する場合は、拡張IDを必ずアプリIDに「.Keyboard」を加えた構造にします。Macで生成・ビルドする場合も未検証です。

## 確認済みと未確認

確認済み：辞書158,801件のSQLite整合性、完全一致・前方一致検索、実践用語OFF時の除外、長い読みやUnicode文字の保存。PC上の検索計測と件数はValidation.jsonに記録しました。PCの時間はiPhone上の速度を保証する数値ではありません。

未確認：Swiftのコンパイル、iOSシミュレータ、実機でのキー配置・フリック・候補選択、メモリ上限、辞書の体感速度、署名・AltStore導入。GitHubのワークフローはシミュレータ用と実機用の両方のビルドを行い、両方成功した場合だけIPAをパッケージ化する設計です。

端末確認では、メモアプリで「ちるぜぱちど」「がんげのむいりょう」「りきっどばいおぷしー」の候補・確定・削除・改行・地球儀切り替えを確認してください。続けて実践ON/OFF、横画面、別アプリへの移動、アプリ復帰を確認します。候補には一般語・誤記を含み得ます。病院向け市販辞書の校閲品質・保守と同等ではありません。

## ソースとライセンス

新規プログラムと加工部分はGPL-2.0。辞書の原典条件（DMiMEとComeJisyoのGPL、万病・百薬のCC BY 4.0）を保持しています。帰属と変更内容はResources/NOTICE.txt、ライセンス本文はResources/、原典READMEとCSVはOriginalSources/にあります。アプリ内の「出典」でも本文を確認できます。2026年10月18日にSQLite変換・キーボードコードを作成しました。原典提供者がこのアプリを承認したという意味ではありません。

Tools/build_dictionary.pyはDictionarySourcesのTXTからSQLiteを再生成し、検索を検査するスクリプトです。SQLiteを変更する場合も、出典と編集可能な入力を残してください。

## 公式資料

- Apple・独自キーボード https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- Apple・キーボードの制約 https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- AltStore Classic・Windows導入 https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
- AltStore・有効期限 https://faq.altstore.io/altstore-classic/your-altstore
- AltStore・App ID https://faq.altstore.io/altstore-classic/app-ids
- GitHub Actions標準ランナー https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- XcodeGen https://github.com/yonaskolb/XcodeGen

上記の導入方法・料金条件は2026年10月18日に公式資料を確認しました。
