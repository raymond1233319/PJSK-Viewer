# PJSK Viewer (日本語)

[![Latest Release](https://img.shields.io/github/v/release/raymond1233319/PJSK-Viewer)](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)

他の言語で読む: [English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

モバイルゲーム「プロジェクトセカイ カラフルステージ！ feat. 初音ミク」関連の情報を閲覧するために設計されたFlutterアプリケーションです。カード、イベント、ガチャ、楽曲などを閲覧できます。最新バージョンは[こちら](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)からダウンロードできます。

## ⚠️ 免責事項
このアプリケーションは表示される素材を所有していません。すべてのクレジットは、セガ、Colorful Palette、クリプトン・フューチャー・メディアを含むがこれらに限定されない、正当な所有者に帰属します。このアプリケーションは、調査および情報提供のみを目的として作成されたファンメイドのデータベースであり、セガまたはColorful Paletteとの公式な提携はありません。

## 特徴

* **情報:** 様々なサーバー地域（一部の機能は日本以外のサーバー地域では利用できない場合があります）のカード、イベント、ガチャ、楽曲、マイセカイに関する情報を表示します。
* **イベントトラッカー:** イベントの進行状況やランキング（ワールドリンクチャプターを含む）を監視するツール。
* **音楽プレーヤー:** お気に入りの曲をストリーミング！
* **ローカリゼーション:** 複数の言語をサポート。
* **オフラインアクセス:** ゲームデータとアセットをローカルにキャッシュし、より高速なアクセスとオフライン表示を実現します。

## 📸 スクリーンショット

| ホーム画面                  | カード                    | イベント                  | イベントトラッカー                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 1](/screenshot/screenshot1.jpg) | ![Screenshot 2](/screenshot/screenshot2.jpg) | ![Screenshot 3](/screenshot/screenshot3.jpg) | ![Screenshot 4](/screenshot/screenshot4.jpg) |

| 楽曲                  | 音楽プレーヤー                    | マイセカイ                  | ガチャ                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 5](/screenshot/screenshot5.jpg) | ![Screenshot 6](/screenshot/screenshot6.jpg) | ![Screenshot 7](/screenshot/screenshot7.jpg) | ![Screenshot 8](/screenshot/screenshot8.jpg) |

## 🐛 既知の問題

* ブルフェスティバルのガチャ確率が正しくない。
* IOS: ダウンロードが機能しない場合があります。
* 既知の問題の完全なリストについては、[公開されている問題](https://github.com/raymond1233319/PJSK-viewer/issues)を参照してください。

## 🗺️ ロードマップ

* 3Dアセットビュー
* スタンプ
* ストーリーリーダー
* カスタマイズ

## 🤝 貢献

貢献を歓迎します！提案やバグを見つけた場合は、まずイシューを開いて変更したい内容について話し合ってください。[翻訳](https://github.com/raymond1233319/PJSK-Viewer/tree/main/assets/localization)に関するアイデアがある場合は、プルリクエストを開いてください。

## 🚀はじめに

ローカルコピーを起動して実行するには、次の簡単な手順に従います。

### 前提条件

* **Flutter SDK:** Flutterがインストールされていることを確認してください。[Flutterインストールガイド](https://docs.flutter.dev/get-started/install)を参照してください。推奨バージョン：[`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml)の`env.FLUTTER_VERSION`を参照してください。
* **IDE:** VS CodeやAndroid StudioなどのFlutterプラグインを備えたIDE。

### インストール

1.  **リポジトリをクローンします:**
    ```bash
    git clone [https://github.com/raymond1233319/PJSK-Viewer.git](https://github.com/raymond1233319/PJSK-Viewer.git)
    cd PJSK-viewer
    ```
2.  **Flutterパッケージを取得します:**
    ```bash
    flutter pub get
    ```
3.  **アプリを実行します:**
    ```bash
    flutter run
    ```

## 📄 ライセンス

Attribution-NonCommercial 4.0 Internationalの下で配布されています。詳細については、`LICENSE`ファイルを参照してください。

## 🙏謝辞

* [Sekai Viewer](https://sekai.best/)からのリソースとインスピレーション。
* FlutterとFlutterチーム。
* このプロジェクトで使用されているすべての素晴らしいパッケージ作成者（[`pubspec.yaml`](pubspec.yaml)を参照）。

