# 群馬をめぐる

群馬の44の訪問先をめぐり、写真と訪問記録を残すiPhoneアプリ。iOS 17以降。

- 現在地が判定範囲内なら朱色の現地スタンプを記録
- 位置情報付き写真からは紫色の写真記録を登録
- 写真一覧、Appleマップ・地理院地図、外部マップへの経路案内
- 44枚の進捗を画像にして共有（写真と場所名の表示を選択可能）

[プライバシーポリシー](PRIVACY.md) · [お問い合わせ](SUPPORT.md)

## ビルド

Macで `python3 iOS/make_project.py` を実行し、`iOS/GunmaJourney.xcodeproj` をXcodeで開く。Signing & Capabilitiesで自分のTeamと固有のBundle Identifierを設定してiPhoneにビルドする。外部パッケージやAPIキーは不要。

## ライセンス

オリジナルのソースコードは[MIT](LICENSE)。地理データ等は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)の条件が適用される。

判定円は立ち入り可能な区域を保証しない。公開された道や施設を利用し、現地の案内に従って訪問する。位置情報は施設への入場や登頂を証明するものではない。
