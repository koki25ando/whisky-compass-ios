# whisky-compass-ios

Whisky Compass の iOS アプリ。Swift + SwiftUI。
バックエンドは `whisky-compass-web` の `/api/v1/` を叩く（Android版と同じAPI・同じDB）。

## 現在の状態：シミュレータで動作確認済み

- ✅ ビルド成功（iPhoneSimulator SDK 26.5 / デプロイターゲット iOS 17.0）
- ✅ ユニットテスト16件・UIテスト3件、全部パス
- ✅ シミュレータ（iPhone 16 Pro / iOS 18.1）で実際に操作して確認：
  ログイン → ホーム → 記録の詳細（レーダーチャート）→ 銘柄ページ →
  マイページ（統計・アカウント削除の導線）→ 新規作成画面
- ⏳ 実機での確認はまだ

UIテストは `WhiskyCompassUITests/SmokeUITests.swift`。**ローカルのDjangoが
起動していることが前提**なので、CIに載せるならバックエンドの起動もセットで必要。

```bash
xcodebuild test -project WhiskyCompass.xcodeproj -scheme WhiskyCompass \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 実装中に見つけて直したもの

1. `EmptyHint` の格納プロパティ名 `body` が `View.body` と衝突（`message`に改名）
2. `@MainActor` クラスの `deinit` から NotificationCenter の購読解除ができない
   （`deinit` は nonisolated）。解除用トークンを別オブジェクトに持たせて解決
3. `@Observable` はクラス継承と噛み合わず、サブクラスのプロパティが監視されない。
   継承をやめて `CheckInListViewModel(source:)` + `ProfileViewModel` の構成に変更
4. ツールバー（戻る・編集・削除）がiOS既定の青。`tint`は`NavigationStack`に
   掛けないとナビゲーションバーに届かない
5. `role: .destructive` の既定の赤が Web/Android の警告色から浮いていた

### Xcode を使えるようにする

`Xcode.app` 本体（26.6）は完全に入っている。問題は**その外側にある共有コンポーネントが
古いまま**なこと。

```
/Applications/Xcode.app                         26.6（2026-06）
/Library/Developer/PrivateFrameworks/CoreDevice 397.24（2024-11）← 古い
```

このズレが `xcodebuild` 起動時の
`Symbol not found: _XPCTypeBool ... CoreDevice.framework` の原因。
Xcodeを新しくしたあと、初回起動時のコンポーネントインストールが済んでいないと起きる。

```bash
# 1. Xcode.app を Finder から一度起動して「追加コンポーネント」を入れる
#    （ターミナルなら以下。どちらも管理者パスワードが必要）
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch

# 2. iOSシミュレータのランタイムを入れる
#    Xcode 16以降は本体と別ダウンロード。7〜10GB程度。
xcodebuild -downloadPlatform iOS

# 3. 確認
xcodebuild -version
xcrun simctl list devices available | grep iPhone
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

### 実装側で済んでいること

| 要件 | 状態 |
|---|---|
| アプリ内アカウント削除（Appleも2022年から必須） | ✅ マイページ |
| **法定飲酒年齢の確認** | ✅ 初回起動時（日本20歳／アメリカ21歳をリージョンで出し分け）＋登録画面にも明示 |
| プライバシーポリシーURL | ✅ https://whiskycompass.app/privacy/ |
| アカウント削除の公開URL | ✅ https://whiskycompass.app/account-deletion/ |
| プライバシーマニフェスト | ✅ `PrivacyInfo.xcprivacy`（UserDefaults の理由 CA92.1 を申告） |
| 輸出コンプライアンス | ✅ `ITSAppUsesNonExemptEncryption: false` |
| アプリアイコン | ✅ 1024x1024・アルファなし |
| ATS例外がReleaseに入らない | ✅ Info.plist を構成ごとに分離 |
| バージョン | ✅ 1.0.0 (build 1) |

### ⚠️ アーカイブ前に必ずやること

```yaml
# project.yml
DEVELOPMENT_TEAM: ""   # ← ここが空だと署名できない
```

値は developer.apple.com/account → Membership details の **Team ID（10文字）**。
秘密情報ではないのでコミットして構わない。設定後は `xcodegen generate` を実行する。

あわせて Developer ポータルで **Bundle ID `app.whiskycompass` の登録**が必要
（Google Play と違い事前登録が要る）。

### 年齢確認について

`Core/Auth/AgeGate.swift`。配信対象が日本とアメリカのみで法定年齢が違う（20歳／21歳）ため、
`Locale.current.region` で出し分ける。**判定できない場合は21歳に倒す**（緩いほうへ倒すと
21歳の国で20歳の表示が出てしまうため）。

確認結果は UserDefaults に「確認したか・何歳基準か・いつか」を保存する。
これが `PrivacyInfo.xcprivacy` で UserDefaults を申告している理由。

⚠️ **現状この確認はiOSアプリ内で完結しており、サーバーには記録していない。**
Android版・Web版には未実装。同じ年齢確認を全プラットフォームに入れるなら、
`accounts.User` に確認日時を持たせてAPIで受けるのが本筋。

### App Store Connect 側で設定するもの

- **配信対象国を日本とアメリカに限定**（アルコール関連アプリを制限する国があるため）
- 年齢レーティング → アルコールへの言及があるため **17+**
- App Privacy（栄養ラベル）→ `PrivacyInfo.xcprivacy` と内容を揃える
- スクリーンショット・説明文・キーワード・サポートURL
- **審査用デモアカウント**（App Review Information）
  → 本番の `appreview@whiskycompass.app`。**このアカウントを削除しないこと**

**Google Play と違い、公開前の必須テスト期間はありません**（12人×14日のような要件は
Apple にはない）。TestFlight は任意で、いきなり審査に出せます。

⚠️ **将来 Google ログインを足す場合**、Apple は「他社のソーシャルログインを提供するなら
Sign in with Apple も同等に提供せよ」と要求します。現在はメール＋パスワードのみなので不要です。
