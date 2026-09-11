# 第三者のデータ・サービス

MITライセンスは第三者のデータやサービスを再許諾するものではありません。

## 市町村の略図

`iOS/GunmaJourney/Resources/municipalities.json`：国土交通省「国土数値情報（行政区域データ）」2025年・群馬県を加工して作成。県外周と市町村境界を抽出・簡略化した写真上の略図です。測量・経路案内には使用しません。

[出典・使用条件](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2025.html) / [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
原典：国土地理院「数値地図（国土基本情報）」等。元の詳細データは同梱していません。元データの再利用では測量法上の手続きが必要な場合があります。

## アイコン

Natural EarthのAdmin 1境界から群馬県を抽出し、形状を用いて独自に描画しました。
[データ](https://github.com/nvkelso/natural-earth-vector) / [Public domain](https://www.naturalearthdata.com/about/terms-of-use/)

## 訪問先座標

`Resources/regions.json`：国土地理院、OpenStreetMap、施設等の資料を参照し、中心・半径を独自調整しています。参照URLは各地点に記載。
© OpenStreetMap contributors. OpenStreetMap由来のデータとその派生データベースには[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)が適用されます。本座標データベースの提供条件もODbL 1.0とします。[OpenStreetMap著作権ページ](https://www.openstreetmap.org/copyright)

## 地図表示

地理院タイル（標準地図）を通信で取得し、ピン・円を重ねています。タイル画像はリポジトリに含みません。
[地理院タイル](https://maps.gsi.go.jp/development/ichiran.html) / [利用規約](https://www.gsi.go.jp/kikakuchousei/kikakuchousei40182.html)
Apple MapsはMapKit経由で表示します。Apple・Google等の商標やサービスにはそれぞれの権利者の条件が適用されます。

## 説明文

独自に作成した説明文に、調査で参照した施設等のURLを付記しています。リンク先の文章・画像をMITで再許諾するものではありません。
