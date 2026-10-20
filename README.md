# おくすリズム

飲み忘れをなくして、あなたの健康をサポートする iOS 服薬管理アプリ。

- 処方薬の飲む時間・量・頻度を登録して通知（通知から「服用を完了する」／10分後に再通知／飲み忘れの再通知）
- 飲み合わせチェック（登録中の薬どうし・新しく飲む薬）
- 一緒にとってはいけない飲食物
- 服薬記録カレンダー・達成率グラフ（週／月／年）
- 残薬数と補充アラート
- アレルギー・副作用歴・持病の登録（登録時に照合）

データはすべて端末内（SwiftData）に保存し、外部へは送信しません。

## 薬データ

`Okusurhythm/Resources/drugs.json` は、PMDA の医療用医薬品添付文書から
よく処方される成分の「併用禁忌」「主な併用注意」「飲食物」を抜き出したものです。
各成分に添付文書ページの URL と改訂年月を持たせています。形式は [data/SCHEMA.md](data/SCHEMA.md)。

```sh
# data/drafts/*.json を編集したら
python3 tools/build_drugs.py         # 形式チェック＋drugs.json を生成
```

> 本アプリの情報は参考情報です。添付文書は改訂されるため、定期的に PMDA の最新版と照合してください。

## 開発

必要なもの: Xcode 26 以降、[XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig   # Team ID と Bundle ID の接頭辞を書く
xcodegen generate
open Okusurhythm.xcodeproj
```

| コマンド | 内容 |
|---|---|
| `scripts/screenshots.sh` | サンプルデータで起動して App Store 用スクリーンショットを撮る |
| `swift tools/make_icon.swift <出力.png>` | アプリアイコンを描き直す |
| 起動引数 `-uiPreview` | メモリ上のサンプルデータで起動（`-initialTab records` / `-screen interactions` など） |

## リリース

```sh
xcodebuild -project Okusurhythm.xcodeproj -scheme Okusurhythm -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Okusurhythm.xcarchive archive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath build/Okusurhythm.xcarchive -exportOptionsPlist ci/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates      # App Store Connect にアップロード
```

プライバシーポリシーとサポートページは `docs/`（GitHub Pages）。
