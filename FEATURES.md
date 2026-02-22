# 장기 마스터 (Janggi Master) - 구현 기능 요약

## 📋 목차
- [기본 게임 기능](#기본-게임-기능)
- [AI 대전 기능](#ai-대전-기능)
- [묘수풀이 (퍼즐) 모드](#묘수풀이-퍼즐-모드)
- [기술적 구현 사항](#기술적-구현-사항)

---

## 🎮 기본 게임 기능

### 1. 장기판 구현
- **9×10 격자판** (파일: `lib/models/board.dart`)
- **초나라(楚/Blue)**: 하단 (0-3 랭크), 선공, 파란색
- **한나라(漢/Red)**: 상단 (6-9 랭크), 후공, 빨간색
- 궁성 대각선 이동 지원

### 2. 기물 배치
4가지 초기 배치 설정 (`lib/models/piece.dart`):
- **마상마상** (내상) - 기본 설정
- **마상상마**
- **상마마상**
- **상마상마**

### 3. 기물 종류 및 이동 규칙
- **차(車)**: 직선 이동
- **포(包)**: 한 기물을 뛰어넘어 이동
- **마(馬)**: ㄱ자 이동 (행마)
- **상(象)**: 용(用)자 이동
- **사(士)**: 궁성 내 대각선 이동
- **병(兵)/졸**: 좌우 + 전진, 궁성 내 대각선
- **장(將)/초(楚)**: 궁성 내 1칸 이동

### 4. 게임 로직
- 체크(장군) 감지
- 체크메이트(외통수) 감지
- 비김(무승부) 감지
- 이동 유효성 검증
- 잡은 기물 표시

---

## 🤖 AI 대전 기능

### 1. Stockfish-Fairy 엔진 통합
- **엔진**: Fairy-Stockfish (Janggi variant 지원)
- **FFI 바인딩**: C++ DLL을 Flutter와 연결
- **파일**: `lib/stockfish_ffi.dart`, `engine/src/c_api.cpp`

### 2. FEN 변환
- Flutter 보드 상태 ↔ Stockfish FEN 형식 변환
- **파일**: `lib/utils/stockfish_converter.dart`
- 좌표계 매핑: Flutter rank (0-9) → Stockfish rank (10-1)

### 3. AI 난이도
3가지 난이도 설정:
- **쉬움**: depth 5, movetime 500ms
- **보통**: depth 10, movetime 1000ms
- **어려움**: depth 15, movetime 2000ms

### 4. 힌트 기능
- AI가 최선의 수를 노란색 화살표로 표시
- MultiPV 설정으로 상위 3개 수 중 랜덤 선택 (60%/30%/10%)
- **파일**: `lib/game/game_state.dart` (getHint 메서드)

---

## 🧩 묘수풀이 (퍼즐) 모드

### 1. GIB 파일 파싱
- **파일**: `lib/utils/gib_parser.dart`
- **인코딩**: EUC-KR, CP949 지원
- **메타데이터 추출**:
  - 대회명, 대국일자, 대국결과
  - 초대국자, 한대국자
  - 기보(수순)

### 2. GIB 좌표계 파싱 (중요!)
```dart
/// GIB 좌표 시스템:
/// - YX 형식 (rank, file) - 첫 번째 숫자가 랭크, 두 번째가 파일
/// - 1-based 인덱싱 (files 1-9, ranks 1-10)
/// - 랭크는 한나라(Red) 쪽부터: rank 1 = 상단 (board rank 9)
///
/// 변환 공식:
/// - boardRank = 10 - gibRank
/// - boardFile = gibFile - 1
```

**예시**: `41漢兵42` (한나라 병 이동)
- From: GIB (4,1) → Board (0, 6)
- To: GIB (4,2) → Board (0, 5)

### 3. 역계산 알고리즘
**목적**: 게임 종료 전 묘수 시작 지점 자동 탐지

**알고리즘** (`findPuzzleStartPosition` 메서드):
1. 게임 끝에서부터 역순으로 진행
2. 각 위치에서 Stockfish로 평가 수행
3. `score cp` (centipawn) → `score mate` (체크메이트) 전환점 탐지
4. 전환점 = 묘수 시작 위치

```dart
// 평가 타입 변화 감지
if (previousType == 'mate' && currentType == 'cp') {
  return moveIdx + 1; // 묘수 시작점 발견!
}
```

### 4. 전처리 시스템
**파일**: `lib/main.dart` (`_testPuzzleExtraction` 메서드)

**프로세스**:
1. Stockfish 초기화
2. GIB 파일 로드 (현재: 기보.gib만)
3. 각 게임에 대해 역계산 수행
4. JSON 형식으로 콘솔에 출력
5. 수동으로 `assets/puzzles/puzzles.json`에 복사

**JSON 구조**:
```json
[
  {
    "file": "기보.gib",
    "gameIndex": 0,
    "title": "홍길동 vs 이순신",
    "description": "제1회 전국대회",
    "startMove": 45,
    "totalMoves": 67,
    "moves": ["41漢兵42", "02楚馬83", ...],
    "metadata": {
      "event": "제1회 전국대회",
      "date": "2024.01.01",
      "result": "초승",
      "bluePlayer": "홍길동",
      "redPlayer": "이순신"
    }
  }
]
```

### 5. 퍼즐 게임 화면
**파일**: `lib/screens/puzzle_game_screen.dart`

**기능**:
- JSON에서 퍼즐 로드
- 지정된 위치까지 자동 재생
- 정해진 수순대로만 이동 가능
- 오답 시 실시간 피드백
- 정답 시 다음 수 진행
- 완료 시 승리 이미지 표시
- AI 힌트 버튼 (노란색 화살표)

**턴 계산 로직**:
```dart
final nextMoveNumber = _replayUpTo + 1;
final currentPlayer = (nextMoveNumber % 2 == 1)
    ? PieceColor.red   // 홀수 수 = 한나라 차례
    : PieceColor.blue; // 짝수 수 = 초나라 차례
```

### 6. 퍼즐 목록 화면
**파일**: `lib/screens/puzzle_list_screen.dart`

- `puzzles.json`에서 퍼즐 로드
- GIB 파일별로 그룹화
- 각 퍼즐의 제목, 수 정보 표시
- 탭으로 퍼즐 선택

---

## 🔧 기술적 구현 사항

### 1. C++ FFI 바인딩 수정
**파일**: `engine/src/c_api.cpp`

**문제**: `getBestMove()` 호출 시 info 라인(score 정보)이 반환되지 않음

**해결책** (lines 276-306):
```cpp
else if (token == "go") {
    // stdout을 캡처하여 info 라인 획득
    std::stringstream info_output;
    std::streambuf* old_cout = std::cout.rdbuf(info_output.rdbuf());

    handle_go(g_pos, is, g_states);
    Threads.main()->wait_for_search_finished();

    // stdout 복원
    std::cout.rdbuf(old_cout);

    // info 라인을 출력 버퍼에 복사
    cout_buffer << info_output.str();

    // bestmove 추가
    // ...
}
```

### 2. 빌드 프로세스
```bash
# DLL 빌드
cd engine/src
g++ -O3 -std=c++17 -DNDEBUG -DIS_64BIT -DUSE_POPCNT \
    -DLARGEBOARDS -DNNUE_EMBEDDING_OFF -DPRECOMPUTED_MAGICS \
    -shared -fPIC -I. [모든 .cpp 파일] \
    -o stockfish.dll -static-libgcc -static-libstdc++

# Flutter 프로젝트에 복사
cp stockfish.dll ../../windows/runner/
cp stockfish.dll ../../
```

### 3. 디버그 스크립트
테스트 및 검증용 독립 실행 파일:
- `debug_gib_coordinates.dart`: GIB 좌표계 테스트
- `debug_gib_1based.dart`: 1-based 인덱싱 검증
- `verify_gib_fix.dart`: 좌표 변환 검증
- `test_puzzle_extraction.dart`: 퍼즐 추출 테스트

### 4. 에셋 구조
```
assets/
├── images/
│   ├── background_1.png
│   ├── 승리이미지.png
│   ├── 패배이미지.png
│   ├── 장군_배경.png
│   ├── 멍군.png
│   └── ...
├── sounds/
│   ├── move.mp3
│   ├── capture.mp3
│   └── check.mp3
└── puzzles/
    ├── 기보.gib (99 게임)
    ├── [기타 .gib 파일들]
    └── puzzles.json (전처리 결과)
```

---

## 🐛 해결된 주요 버그

### 1. GIB 좌표 파싱 오류
- **증상**: 기물이 잘못된 위치에 배치, 초 장군 누락
- **원인**: XY 형식으로 잘못 해석, 랭크 변환 오류
- **해결**: YX 형식 + 올바른 변환 공식 적용

### 2. 턴 순서 오류
- **증상**: 퍼즐 시작 시 잘못된 플레이어 차례
- **원인**: 재생 후 턴 계산 로직 오류
- **해결**: `nextMoveNumber = _replayUpTo + 1` 사용

### 3. 조기 게임 종료
- **증상**: 퍼즐 로드 시 즉시 게임 오버 이미지 표시
- **원인**: `setPuzzlePosition()`에서 `_updateStatusMessage()` 호출
- **해결**: 체크메이트 검사 제거

### 4. Stockfish 미초기화 오류
- **증상**: "Bad state: Stockfish not initialized"
- **해결**: `puzzle_game_screen.dart`의 `initState()`에 `StockfishFFI.init()` 추가

### 5. 앱 크래시 (역계산 중)
- **증상**: "Lost connection to device" - 전처리 중 크래시
- **원인**: `getBestMove()`가 info 라인 반환 안 함
- **해결**: C++ wrapper 수정하여 stdout 캡처

---

## 📊 현재 상태

### ✅ 완료된 기능
- [x] 기본 장기 게임 로직
- [x] AI 대전 (3가지 난이도)
- [x] AI 힌트 기능
- [x] GIB 파일 파싱
- [x] GIB 좌표계 정확한 변환
- [x] 역계산 알고리즘 구현
- [x] 퍼즐 모드 UI
- [x] 퍼즐 정답 검증
- [x] 승리/패배 이미지 표시
- [x] C++ FFI stdout 캡처 수정

### 🔄 진행 중
- [ ] 기보.gib (99 게임) 전처리 테스트
- [ ] JSON 출력 → puzzles.json 복사
- [ ] 전체 GIB 파일 전처리 (2000+ 게임)

### 📝 향후 개선 사항
- [ ] 자동 JSON 저장 (수동 복사 불필요)
- [ ] 전처리 진행률 표시
- [ ] 퍼즐 난이도 표시
- [ ] 퍼즐 통계 (성공률, 시도 횟수)
- [ ] 배경 음악 및 효과음
- [ ] 온라인 대전 모드

---

## 🎯 다음 단계

1. **앱 실행 및 전처리 테스트**
   - "TEST 묘수 추출" 버튼 클릭
   - 콘솔에서 JSON 출력 확인
   - `assets/puzzles/puzzles.json`에 복사

2. **단일 파일 검증**
   - 기보.gib의 99개 게임 분석 결과 확인
   - 묘수 시작 지점 적절성 검토

3. **전체 확장**
   - 모든 GIB 파일로 확장
   - 2000+ 퍼즐 생성

---

## 📚 참고 문서

- **GIB 형식**: 한국 장기 기보 표준 형식
- **Fairy-Stockfish**: https://github.com/fairy-stockfish/Fairy-Stockfish
- **UCI 프로토콜**: Universal Chess Interface
- **Flutter FFI**: https://dart.dev/guides/libraries/c-interop

---

**마지막 업데이트**: 2026-01-12
**버전**: 1.0.0
**개발자**: Claude Sonnet 4.5 + User
