# PJSK Viewer (简体中文)

[![Latest Release](https://img.shields.io/github/v/release/raymond1233319/PJSK-Viewer)](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)

阅读其他语言版本：[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [繁體中文](README.zh-TW.md)

一个 Flutter 应用程序，旨在查看与手机游戏《Project SEKAI COLORFUL STAGE! feat. Hatsune Miku》相关的信息。浏览卡片、活动、扭蛋、音乐等。最新版本可从[此处](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)下载。

## ⚠️ 免责声明
此应用程序不拥有所显示的材料。所有版权归其合法所有者所有，包括但不限于 Sega、Colorful Palette 和 Crypton Future Media。此应用程序是一个粉丝制作的数据库，仅用于研究和信息目的，与 Sega 或 Colorful Palette 没有任何官方隶属关系。

## 功能

* **信息：** 查看各个服务器区域（某些功能可能在除日服以外的服务器区域不可用）的卡片、活动、扭蛋、音乐和 mysekai 的信息。
* **活动追踪器：** 监控活动进度或排名（包括世界链接章节）的工具。
* **音乐播放器：** 播放您最喜爱的歌曲！
* **本地化：** 支持多种语言。
* **离线访问：** 在本地缓存游戏数据和资产，以便更快地访问和离线查看。


## 📸 屏幕截图

| 主屏幕                  | 卡片                    | 活动                  | 活动追踪器                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 1](/screenshot/screenshot1.jpg) | ![Screenshot 2](/screenshot/screenshot2.jpg) | ![Screenshot 3](/screenshot/screenshot3.jpg) | ![Screenshot 4](/screenshot/screenshot4.jpg) |

| 音乐                  | 音乐播放器                    | My Sekai                  | 扭蛋                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 5](/screenshot/screenshot5.jpg) | ![Screenshot 6](/screenshot/screenshot6.jpg) | ![Screenshot 7](/screenshot/screenshot7.jpg) | ![Screenshot 8](/screenshot/screenshot8.jpg) |


## 🐛 已知问题

* Bloom Festival的扭蛋概率不正确。
* iOS：下载可能无法正常工作。
* 有关已知问题的完整列表，请参阅[未解决的问题](https://github.com/raymond1233319/PJSK-viewer/issues)。

## 🗺️ 路线图

* 3D 模型查看
* 贴纸
* 剧情阅读器
* 自定义

## 🤝 贡献

欢迎贡献！如果您有任何建议或发现错误，请先提出一个 issue 来讨论您想要更改的内容。如果您对[翻译](https://github.com/raymond1233319/PJSK-Viewer/tree/main/assets/localization)有任何想法，请提交一个 pull request。

## 🚀 开始使用

要获取本地副本并运行，请按照以下简单步骤操作。

### 先决条件

* **Flutter SDK：** 确保您已安装 Flutter。请参阅 [Flutter 安装指南](https://docs.flutter.dev/get-started/install)。推荐版本：请参阅 [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml) 中的 `env.FLUTTER_VERSION`。
* **IDE：** 像 VS Code 或 Android Studio 这样带有 Flutter 插件的 IDE。

### 安装

1.  **克隆仓库：**
    ```bash
    git clone [https://github.com/raymond1233319/PJSK-Viewer.git](https://github.com/raymond1233319/PJSK-Viewer.git)
    cd PJSK-viewer
    ```
2.  **获取 Flutter 包：**
    ```bash
    flutter pub get
    ```
3.  **运行应用程序：**
    ```bash
    flutter run
    ```


## 📄 许可证

根据 Attribution-NonCommercial 4.0 International 分发。有关更多信息，请参阅 `LICENSE` 文件。

## 🙏 致谢

* 资源和灵感来自 [Sekai Viewer](https://sekai.best/)。
* Flutter 和 Flutter 团队。
* 本项目中使用的所有出色的包作者（请参阅 [`pubspec.yaml`](pubspec.yaml)）。

