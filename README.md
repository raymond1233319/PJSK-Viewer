# PJSK Viewer

[![Latest Release](https://img.shields.io/github/v/release/raymond1233319/PJSK-Viewer)](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)

Read this in other languages: [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

A Flutter application designed to view information related to the mobile game *Project SEKAI COLORFUL STAGE! feat. Hatsune Miku*. Browse cards, events, gachas, music, and more. The latest version can be downloaded from [here](https://github.com/raymond1233319/PJSK-Viewer/releases/latest).

## ⚠️ Disclaimer
This application does not own the materials displayed. All credits go to its rightful owners, including but not limited to Sega, Colorful Palette, and Crypton Future Media. This application is a fan-made database created for research and informational purposes only and has no official affiliation with Sega or Colorful Palette.

## Features

* **Information:** View information about cards, event, gachas, music and mysekai on various server region (some feature may not available in server region other than jp).
* **Event Tracker:** Tools to monitor event progress or rankings (including world link chapter).
* **Music Player:** Stream your favourite song!
* **Localization:** Supports multiple languages.
* **Offline Access:** Caches game data and asset locally for faster access and offline viewing.


## 📸 Screenshots

| Home Screen                  | Card                    | Event                  | Event Tracker                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 1](/screenshot/screenshot1.jpg) | ![Screenshot 2](/screenshot/screenshot2.jpg) | ![Screenshot 3](/screenshot/screenshot3.jpg) | ![Screenshot 4](/screenshot/screenshot4.jpg) |

| Music                  | Music Player                    | My Sekai                  | Gacha                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 5](/screenshot/screenshot5.jpg) | ![Screenshot 6](/screenshot/screenshot6.jpg) | ![Screenshot 7](/screenshot/screenshot7.jpg) | ![Screenshot 8](/screenshot/screenshot8.jpg) |


## 🐛 Known Issues

* Incorrect gacha rate for bloom festival.
* IOS: Download may not function.
* See the [open issues](https://github.com/raymond1233319/PJSK-viewer/issues) for a full list of known issues.

## 🗺️ Roadmap

* 3D Asset View
* Sticker
* Story reader
* Customization

## 🤝 Contributing

Contributions are welcome! If you have suggestions or find bugs, please open an issue first to discuss what you would like to change. If you have any idea in [translation](https://github.com/raymond1233319/PJSK-Viewer/tree/main/assets/localization), please open a pull request.

## 🚀 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

* **Flutter SDK:** Ensure you have Flutter installed. See the [Flutter installation guide](https://docs.flutter.dev/get-started/install). Recommended version: See `env.FLUTTER_VERSION` in [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml).
* **IDE:** An IDE like VS Code or Android Studio with the Flutter plugin.

### Installation

1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/raymond1233319/PJSK-Viewer.git](https://github.com/raymond1233319/PJSK-Viewer.git)
    cd PJSK-viewer
    ```
2.  **Get Flutter packages:**
    ```bash
    flutter pub get
    ```
3.  **Run the app:**
    ```bash
    flutter run
    ```


## 📄 License

Distributed under the Attribution-NonCommercial 4.0 International. See `LICENSE` file for more information.

## 🙏 Acknowledgements

* Resource and inspiration from [Sekai Viewer](https://sekai.best/).
* Flutter and the Flutter team.
* All the amazing package authors used in this project (see [`pubspec.yaml`](pubspec.yaml)).

