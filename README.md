# whisky-compass-ios

Whisky Compass の iOS アプリ。Swift + SwiftUI。
バックエンドは `whisky-compass-web` の `/api/v1/` を叩く（Android版と同じAPI・同じDB）。

## ⚠️ 現在の状態：未ビルド

**このプロジェクトは一度もビルドされていません。** 開発機の Xcode.app が
4.0GB しかなく（完全版は15GB以上）、`xcodebuild` がライブラリの読み込みに失敗する
状態だったため、コンパイル検証ができていません。

済んでいるのは以下だけです：

- 全24ファイルの **構文チェック**（`swiftc -parse`、エラーなし）
- `xcodegen generate` によるプロジェクト生成

**型エラー・API不一致は残っている前提**で、最初のビルドに臨んでください。
Android版も同じ経緯（環境が揃う前にコードを書いた）でしたが、初回ビルドは
インポート漏れ2件の修正で通りました。

### Xcode を使えるようにする

```bash
# 1. Xcode のインストールを完了させる（App Store で「再開」または再インストール）
du -sh /Applications/Xcode.app     # 15GB以上あればOK

# 2. コマンドラインの向き先を Xcode に切り替える（要パスワード）
sudo xcode-select -s /Applications/Xcode.app

# 3. 確認
xcodebuild -version
```

## セットアップ

`.xcodeproj` はマージ競合の温床なのでコミットしていません。`project.yml` が正で、
プロジェクトはそこから生成します。

```bash
brew install xcodegen     # 未インストールなら
cd whisky-compass-ios
xcodegen generate
open WhiskyCompass.xcodeproj
```

**`project.yml` を変えたら `xcodegen generate` を再実行**してください。
ファイルを追加したときも同様です（`WhiskyCompass/` 以下を丸ごと拾う設定なので、
Xcode上での手動追加は不要）。

## ローカルでの動かし方

### 1. バックエンドを起動

**本番の Supabase を汚さないよう、必ずローカル SQLite で起動すること。**

```bash
cd ../whisky-compass-web
source .venv/bin/activate

export DATABASE_URL="sqlite:///../whisky-compass-db/dev.sqlite3"
export SUPABASE_S3_ACCESS_KEY_ID=""
export DJANGO_DEBUG=True
export DJANGO_ALLOWED_HOSTS="localhost,127.0.0.1,10.0.2.2"

python manage.py runserver 0.0.0.0:8000
```

### 2. シミュレータで実行

そのまま Run するだけです。**iOSシミュレータは Mac のネットワークをそのまま使う**ので、
`http://localhost:8000` で届きます（Androidエミュレータで必要だった `10.0.2.2` への
読み替えは不要）。

平文HTTPは iOS が既定で禁止しますが、`project.yml` の `NSAllowsLocalNetworking` で
**ローカルネットワーク宛てだけ**許可しています。公開ドメインへの平文通信は禁止のままです。

テストアカウントは `test@example.com` / `test`（`create_test_user` で作成）。

### 3. 実機で試す

`APIClient.baseURL` の Debug 側を Mac の LAN IP に変え、`DJANGO_ALLOWED_HOSTS` にも
同じIPを足してください。実機は `localhost` では Mac に届きません。

## 構成

```
WhiskyCompass/
├── WhiskyCompassApp.swift        エントリポイント
├── RootView.swift                セッション判定と画面遷移(Route)
├── Core/
│   ├── Network/                  APIClient・DTO・エラー翻訳・multipart組み立て
│   ├── Auth/TokenStore.swift     トークン保管(Keychain)
│   ├── Data/                     リポジトリ・フレーバー軸・下書き
│   ├── UI/                       配色・共通部品・レーダーチャート
│   └── Util/                     相対時刻・画像圧縮
└── Features/
    ├── Auth/                     ログイン・サインアップ
    ├── Feed/                     ホーム（全体フィード）・カード・一覧のページング
    ├── Detail/                   記録の詳細・写真の全画面表示
    ├── Editor/                   新規作成と編集（同じ画面を使い回す）
    ├── MyPage/                   統計・ログアウト・アカウント削除
    └── Whisky/                   銘柄ページ（コミュニティ集計）
```

### Android版との対応

同じ機能・同じ配色・同じ判断を移植しています。プラットフォーム都合で違うのは以下だけです。

| | Android | iOS |
|---|---|---|
| ローカル開発の接続先 | `10.0.2.2:8000` | `localhost:8000` |
| 平文HTTPの許可 | `network_security_config.xml`（debugのみ） | `NSAllowsLocalNetworking` |
| トークン保管 | DataStore + Keystore暗号化 | Keychain |
| 通信 | Retrofit + OkHttp | URLSession + async/await |
| 写真選択 | PickMultipleVisualMedia | PhotosPicker |
| 一覧の再取得通知 | `CheckInRepository.changes`(Flow) | `NotificationCenter` |

### 設計上の決めごと（Android版と共通）

- **フレーバーは明示的にONにされたときだけ送る。** 触っていないスライダーの初期値5を
  保存すると、プロダクトの資産であるフレーバーデータに中央値が混ざる
- **フレーバーはアプリ内でも0〜10のまま扱う。** 0〜1正規化はサーバーの内側
- **軸の順序をサーバーと一致させる。** ズレるとレーダーの意味が変わるのでテストで固定
- **レーダーチャートは Canvas で自前描画。** ライブラリを噛ませるより軽い
- **評価は★10個並べず「★ 9 / 10」で見せる。** 10個の星は数を数えさせてしまう
- **一覧の再取得はデータを変更した側から通知する。** 画面のライフサイクルに頼ると
  「戻ってきたのに消したはずの記録が残る」取りこぼしが起きる

## App Store 提出に向けて

Android版で用意したものがそのまま使えます。

| 要件 | 状態 |
|---|---|
| アプリ内アカウント削除（Appleも2022年から必須） | ✅ 実装済み（マイページ） |
| プライバシーポリシーURL | ✅ https://whiskycompass.app/privacy/ |
| アカウント削除の公開URL | ✅ https://whiskycompass.app/account-deletion/ |
| 年齢レーティング | アルコールへの言及があるため17+相当 |
| Apple Developer Program | ❌ 未加入（$99/年） |
| App Privacy（栄養ラベル） | ❌ 未記入 |

**Google Play と違い、公開前の必須テスト期間はありません**（12人×14日のような要件は
Apple にはない）。TestFlight は任意で、いきなり審査に出せます。

⚠️ **将来 Google ログインを足す場合**、Apple は「他社のソーシャルログインを提供するなら
Sign in with Apple も同等に提供せよ」と要求します。現在はメール＋パスワードのみなので不要です。
