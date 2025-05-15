# PJSK Viewer (한국어)

[![Latest Release](https://img.shields.io/github/v/release/raymond1233319/PJSK-Viewer)](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)

다른 언어로 읽기: [English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

모바일 게임 *프로젝트 세카이 컬러풀 스테이지! feat. 하츠네 미쿠* 관련 정보를 보도록 설계된 Flutter 애플리케이션입니다. 카드, 이벤트, 가챠, 음악 등을 찾아보세요. 최신 버전은 [여기](https://github.com/raymond1233319/PJSK-Viewer/releases/latest)에서 다운로드할 수 있습니다.

## ⚠️ 면책 조항
이 애플리케이션은 표시되는 자료를 소유하지 않습니다. 모든 크레딧은 Sega, Colorful Palette 및 Crypton Future Media를 포함하되 이에 국한되지 않는 정당한 소유자에게 있습니다. 이 애플리케이션은 연구 및 정보 제공 목적으로만 제작된 팬 제작 데이터베이스이며 Sega 또는 Colorful Palette와 공식적인 제휴 관계가 없습니다.

## 기능

* **정보:** 다양한 서버 지역(일부 기능은 일본 이외의 서버 지역에서는 사용하지 못할 수 있음)의 카드, 이벤트, 가챠, 음악 및 마이세카이에 대한 정보를 봅니다.
* **이벤트 추적기:** 이벤트 진행 상황 또는 순위(월드 링크 챕터 포함)를 모니터링하는 도구입니다.
* **음악 플레이어:** 좋아하는 노래를 스트리밍하세요!
* **현지화:** 여러 언어를 지원합니다.
* **오프라인 액세스:** 더 빠른 액세스 및 오프라인 보기를 위해 게임 데이터와 자산을 로컬에 캐시합니다.


## 📸 스크린샷

| 홈 화면                  | 카드                    | 이벤트                  | 이벤트 추적기                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 1](/screenshot/screenshot1.jpg) | ![Screenshot 2](/screenshot/screenshot2.jpg) | ![Screenshot 3](/screenshot/screenshot3.jpg) | ![Screenshot 4](/screenshot/screenshot4.jpg) |

| 음악                  | 음악 플레이어                    | 마이 세카이                  | 가챠                 |
| :--------------------------: | :--------------------------: | :--------------------------: | :--------------------------: |
| ![Screenshot 5](/screenshot/screenshot5.jpg) | ![Screenshot 6](/screenshot/screenshot6.jpg) | ![Screenshot 7](/screenshot/screenshot7.jpg) | ![Screenshot 8](/screenshot/screenshot8.jpg) |


## 🐛 알려진 문제점

* 블룸 페스티벌의 가챠 확률이 잘못되었습니다.
* IOS: 다운로드가 작동하지 않을 수 있습니다.
* 알려진 문제의 전체 목록은 [열린 문제](https://github.com/raymond1233319/PJSK-viewer/issues)를 참조하십시오.

## 🗺️ 로드맵

* 3D 자산 보기
* 스티커
* 스토리 리더
* 사용자 지정

## 🤝 기여하기

기여를 환영합니다! 제안 사항이 있거나 버그를 발견하면 먼저 문제를 열어 변경하고 싶은 내용을 논의하십시오. [번역](https://github.com/raymond1233319/PJSK-Viewer/tree/main/assets/localization)에 대한 아이디어가 있으면 풀 리퀘스트를 여십시오.

## 🚀 시작하기

로컬 복사본을 설치하고 실행하려면 다음 간단한 단계를 따르십시오.

### 전제 조건

* **Flutter SDK:** Flutter가 설치되어 있는지 확인하십시오. [Flutter 설치 가이드](https://docs.flutter.dev/get-started/install)를 참조하십시오. 권장 버전: [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml)의 `env.FLUTTER_VERSION`을 참조하십시오.
* **IDE:** Flutter 플러그인이 있는 VS Code 또는 Android Studio와 같은 IDE.

### 설치

1.  **리포지토리 복제:**
    ```bash
    git clone [https://github.com/raymond1233319/PJSK-Viewer.git](https://github.com/raymond1233319/PJSK-Viewer.git)
    cd PJSK-viewer
    ```
2.  **Flutter 패키지 가져오기:**
    ```bash
    flutter pub get
    ```
3.  **앱 실행:**
    ```bash
    flutter run
    ```


## 📄 라이선스

Attribution-NonCommercial 4.0 International에 따라 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하십시오.

## 🙏 감사 인사

* [Sekai Viewer](https://sekai.best/)의 리소스 및 영감.
* Flutter 및 Flutter 팀.
* 이 프로젝트에 사용된 모든 훌륭한 패키지 작성자 ( [`pubspec.yaml`](pubspec.yaml) 참조).

