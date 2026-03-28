# 장기 한수

Flutter 기반 장기 훈련 앱입니다.  
AI 대국, 묘수풀이, 이어하기 분석, 커스텀 퍼즐 제작과 공유를 한 앱 안에서 다루는 것을 목표로 합니다.

## 요약

- Fairy-Stockfish 기반 AI 훈수/대국
- 재검증한 묘수풀이 카탈로그
- 원하는 배치를 만든 뒤 AI 대국 또는 로컬 분석으로 이어하기
- 커스텀 퍼즐 제작 및 공유 코드 지원
- Android 중심 베타 테스트 진행 중

## 현재 핵심 기능

### 1. AI 대국

- Fairy-Stockfish 엔진을 Dart FFI로 연결
- 난이도 조절 지원
- 힌트 제공
- 장기 규칙을 앱 내부에서도 직접 검증

### 2. 묘수풀이

- 퍼즐 시작 포지션과 수순을 앱 기준으로 다시 검증
- 저장된 정답 수순에서 벗어나도, 주어진 수 안에 실제 외통이면 성공 처리
- 푼 퍼즐은 목록과 카테고리에서 진행 상태 표시

현재 기본 퍼즐 수:

- 1수 외통: 159
- 2수 외통: 35
- 3수 외통: 3
- 총합: 197

### 3. 이어하기 분석

- 배치를 자유롭게 만든 뒤 바로 이어서 둘 수 있음
- `이어하기(AI)`로 AI 대국 시작 가능
- `로컬 분석`으로 혼자 수읽기/복기 가능

### 4. 커스텀 퍼즐

- 직접 배치하고 퍼즐 생성
- 공유 코드 기반으로 퍼즐 전달 가능

### 5. 스킨/표현

- 한국 장기풍 기본 스킨 추가
- 기존 금빛 스타일은 레거시 스킨으로 유지
- 보드/기물 스킨 설정 지원

## 최근 정리된 내용

- 퍼즐 카탈로그를 다시 검증해서 불안정한 퍼즐 제거
- 궁성 내 차/포 대각 이동 판정 수정
- 일부 퍼즐의 체크메이트/종국 처리 개선
- 퍼즐 완료 표시 추가
- 이어하기 로컬 분석 기능 추가
- 힌트/평가 UI와 대국 준비 UI 일부 정리

## 기술 스택

- Frontend: Flutter
- Engine: C++ / Fairy-Stockfish
- Integration: Dart FFI
- State Management: Provider
- Platforms: Android, Windows

## 시작하기

### 요구 사항

- Flutter SDK
- Android Studio 또는 Visual Studio
- Android 개발 환경 또는 Windows Flutter 개발 환경

### 설치

```bash
git clone https://github.com/Sungi-Hwang/janggi_project.git
cd janggi_project/janggi_master
flutter pub get
```

### 실행

Android:

```bash
flutter run
```

Windows:

```bash
flutter run -d windows
```

## 테스트 / 검증

예시:

```bash
flutter analyze
flutter test
```

## 프로젝트 구조

- `lib/`: Flutter 앱 코드
- `engine/`: Fairy-Stockfish 엔진 소스
- `assets/`: 퍼즐, 이미지, 폰트, 사운드
- `tool/`: 퍼즐 검증/분리/빌드용 도구
- `test/`: 회귀 테스트
- `docs/`: 베타 운영, 퍼즐 자동화, 홍보 자료 정리

## 라이선스

엔진 코드는 [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish)를 기반으로 하며 GPLv3 라이선스를 따릅니다.
