# 장기한수 (Janggi Master)

Flutter 기반 장기(한국 장기) 앱 프로젝트입니다.  
실시간 AI 대국, 오프라인 2인 대국, 이어하기, 묘수풀이(기보 기반/사용자 생성) 기능을 제공합니다.

## 앱 소개

- 프로젝트명: `janggi_project`
- 앱 디렉터리: `janggi_master/`
- 핵심 목표:
  - 모바일에서 쾌적하게 장기를 둘 수 있는 UI/UX
  - Fairy-Stockfish 기반 AI 대국 제공
  - 실제 기보(GIB)에서 전술 장면을 추출해 묘수풀이 콘텐츠화

## 주요 기능

- AI 대국 (난이도별 대응)
- 오프라인 2인 대국
- 이어하기 대국
- 묘수풀이 모드
- 나만의 묘수 생성/편집
- 장기판/기물 렌더링 및 효과음

## 기술 스택

- 앱 프레임워크: `Flutter` / `Dart (SDK ^3.6.1)`
- 상태 관리: `Provider`
- 로컬 저장: `SharedPreferences`
- 사운드: `audioplayers`
- 엔진 연동: `Dart FFI` + `C++`
- 장기 AI 엔진: `Fairy-Stockfish` 기반 커스텀 빌드
- 대상 플랫폼: Android 중심, Windows 포함 멀티플랫폼 구조

## 어려웠던 점과 오류 해결 과정

### 1. GIB 좌표계 파싱 오류

- 문제:
  - 기보를 읽으면 기물이 잘못된 칸에 배치되거나 초반 배치가 깨짐.
- 원인:
  - GIB 좌표를 `XY`로 해석했지만 실제 포맷은 `YX(rank, file)` 구조.
- 해결:
  - 변환 로직을 `boardRank = 10 - gibRank`, `boardFile = gibFile - 1`로 정정.
  - 파서 및 검증 스크립트로 좌표 매핑 재검증.

### 2. AI 수 파싱(multiPV) 오류

- 문제:
  - AI가 수(`e9f9`) 대신 `"1"`, `"2"` 같은 값 반환.
- 원인:
  - UCI `info ... multipv 1 ... pv e9f9 ...` 파싱 시 `pv` 탐색이 잘못되어 `multipv`의 숫자를 읽음.
- 해결:
  - 파싱 조건을 `' pv '` 기반으로 변경하고 시작 인덱스 계산 보정.
  - 로깅 추가로 실제 파싱 라인/결과 추적.

### 3. 궁성 대각선(차) 체크 판정 오류

- 문제:
  - 궁성 내부 대각선 경로에서 차가 장군을 걸어도 체크가 누락되는 케이스 발생.
- 원인:
  - "기물 색" 기준으로 궁성 판정을 해 상대 궁성 침투 상황을 정확히 반영하지 못함.
- 해결:
  - 기물 색이 아닌 **실제 좌표(from/to)** 기준으로 어느 궁성인지 판정하도록 로직 재작성.
  - 대각선 경로/막힘 조건을 별도 함수로 분리해 검증.

### 4. 묘수풀이 화면 Stockfish 초기화 오류

- 문제:
  - `"Bad state: Stockfish not initialized"` 예외 발생.
- 원인:
  - 화면 초기화 단계에서 엔진 init 누락.
- 해결:
  - 묘수풀이 화면 `initState()`에서 엔진 초기화 호출 보장.

## 프로젝트 구조

```text
janggi_project/
├─ README.md
└─ janggi_master/
   ├─ lib/                # Flutter UI/게임 로직
   ├─ engine/             # Fairy-Stockfish 기반 C++ 엔진 소스
   ├─ assets/             # 이미지/사운드/기보/묘수 데이터
   ├─ android/            # Android 설정
   ├─ windows/            # Windows 설정
   └─ tools/              # 배지/에셋 생성 등 스크립트
```

## 실행 방법

```bash
git clone https://github.com/Sungi-Hwang/janggi_project.git
cd janggi_project/janggi_master
flutter pub get
flutter run
```

Windows 실행:

```bash
flutter run -d windows
```

## 라이선스 참고

- 엔진 코드는 Fairy-Stockfish 기반이며, 해당 엔진 라이선스(GPL 계열) 정책을 따릅니다.
- 세부 내용은 `janggi_master/engine/Copying.txt`를 참고하세요.
