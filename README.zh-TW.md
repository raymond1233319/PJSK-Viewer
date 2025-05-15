# PJSK Viewer (繁體中文)

[![Latest Release](https://img.shields.io/github/v/release/raymond1233319/PJSK-Viewer)](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)

閱讀其他語言版本：[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

一個 Flutter 應用程式，旨在檢視與手機遊戲《世界計畫 多彩舞台！ feat. 初音未來》相關的資訊。瀏覽卡片、活動、轉蛋、音樂等。最新版本可從[此處](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)下載。

## ⚠️ 免責聲明
此應用程式不擁有顯示的素材。所有版權歸其合法所有者所有，包括但不限於 Sega、Colorful Palette 和 Crypton Future Media。此應用程式是一個粉絲製作的資料庫，僅用於研究和資訊目的，與 Sega 或 Colorful Palette 沒有任何官方隸屬關係。

## 功能

* **資訊：** 檢視各個伺服器區域（某些功能可能在除日服以外的伺服器區域不可用）的卡片、活動、轉蛋、音樂和 mysekai 的資訊。
* **活動追蹤器：** 監控活動進度或排名（包括世界連結章節）的工具。
* **音樂播放器：** 播放您最喜愛的歌曲！
* **本地化：** 支援多種語言。
* **離線存取：** 在本地快取遊戲資料和資產，以便更快地存取和離線檢視。


## 📸 螢幕截圖

| 主螢幕                  | 卡片                    | 活動                  | 活動追蹤器                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 1](/screenshot/screenshot1.jpg) | ![Screenshot 2](/screenshot/screenshot2.jpg) | ![Screenshot 3](/screenshot/screenshot3.jpg) | ![Screenshot 4](/screenshot/screenshot4.jpg) |

| 音樂                  | 音樂播放器                    | My Sekai                  | 轉蛋                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 5](/screenshot/screenshot5.jpg) | ![Screenshot 6](/screenshot/screenshot6.jpg) | ![Screenshot 7](/screenshot/screenshot7.jpg) | ![Screenshot 8](/screenshot/screenshot8.jpg) |


## 🐛 已知問題

* Bloom Festival的轉蛋機率不正確。
* iOS：下載可能無法正常運作。
* 有關已知問題的完整列表，請參閱[未解決的問題](https://github.com/raymond1233319/PJSK-viewer/issues)。

## 🗺️ 路線圖

* 3D 模型檢視
* 貼圖
* 劇情閱讀器
* 自訂

## 🤝 貢獻

歡迎貢獻！如果您有任何建議或發現錯誤，請先提出一個 issue 來討論您想要變更的內容。如果您對[翻譯](https://github.com/raymond1233319/PJSK-Viewer/tree/main/assets/localization)有任何想法，請提交一個 pull request。

## 🚀 開始使用

要取得本地副本並執行，請按照以下簡單步驟操作。

### 先決條件

* **Flutter SDK：** 確保您已安裝 Flutter。請參閱 [Flutter 安裝指南](https://docs.flutter.dev/get-started/install)。建議版本：請參閱 [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml) 中的 `env.FLUTTER_VERSION`。
* **IDE：** 像 VS Code 或 Android Studio 這樣帶有 Flutter 套件的 IDE。

### 安裝

1.  **複製儲存庫：**
    ```bash
    git clone [https://github.com/raymond1233319/PJSK-Viewer.git](https://github.com/raymond1233319/PJSK-Viewer.git)
    cd PJSK-viewer
    ```
2.  **取得 Flutter 套件：**
    ```bash
    flutter pub get
    ```
3.  **執行應用程式：**
    ```bash
    flutter run
    ```


## 📄 授權條款

根據 Attribution-NonCommercial 4.0 International 分發。有關更多資訊，請參閱 `LICENSE` 檔案。

## 🙏 致謝

* 資源和靈感來自 [Sekai Viewer](https://sekai.best/)。
* Flutter 和 Flutter 團隊。
* 本專案中使用的所有出色的套件作者（請參閱 [`pubspec.yaml`](pubspec.yaml)）。

