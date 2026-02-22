# 장기 마스터 - 버그 수정 로그

**작성일**: 2026-01-12
**세션**: 퍼즐 모드 구현 및 버그 수정

---

## 📋 목차
- [작업 요약](#작업-요약)
- [발견된 버그 및 해결](#발견된-버그-및-해결)
- [현재 상태](#현재-상태)
- [미해결 이슈](#미해결-이슈)
- [기술 노트](#기술-노트)

---

## 🎯 작업 요약

### 완료된 작업
1. ✅ GIB 파일 좌표계 파싱 수정
2. ✅ 퍼즐 모드 턴 순서 수정
3. ✅ AI 힌트 기능 통합
4. ✅ 조기 게임 종료 버그 수정
5. ✅ AI 대전 "multipv" 파싱 버그 수정
6. ✅ C++ FFI stdout 캡처 시도 및 롤백
7. ✅ FEATURES.md 문서 작성
8. ✅ BUGFIX_LOG.md 문서 작성 (현재)

### 완료된 추가 작업 (2026-02-04)
- ✅ **안정적인 묘수 추출 시스템 구축**: 프로세스 격리 방식으로 Stockfish DLL 크래시 문제 해결.
- ✅ **난이도별 묘수 데이터 수집**: 1수(16개), 2수(5개), 3수(1개) 총 22개 묘수 추출 완료.
- ✅ **묘수풀이 모드 UI/UX 개선**: 난이도(1/2/3수)별 카테고리 분류 및 선택 화면 구현.
- ✅ **FEN 기반 배치 및 UCI 수순 검증**: 정밀한 기물 배치와 연속 정답 수순 체크 기능 구현.

### 진행 중
- 🔄 역계산 알고리즘 구현 (기술적 제약으로 보류)
- 🔄 퍼즐 전처리 시스템

---

## 🐛 발견된 버그 및 해결

### 버그 #1: GIB 좌표 파싱 오류 ✅

**발견 날짜**: 이전 세션
**심각도**: 🔴 Critical

**증상**:
- 기물이 잘못된 위치에 배치됨
- 초(Blue) 장군이 보드에 나타나지 않음
- 첫 수 재생 시 기물이 엉뚱한 곳으로 이동

**사용자 피드백**:
> "이거 첫 수를 보면 그때 장기 첫 시작배치랑 동일할거아냐 그때를봐바"

**원인**:
```dart
// 잘못된 해석 (XY 형식)
final gibFromFile = int.parse(coordMatch.group(1)!);  // ❌
final gibFromRank = int.parse(coordMatch.group(2)!);  // ❌
```

GIB 형식은 **YX (rank, file)** 순서인데 XY로 해석

**해결** (`lib/utils/gib_parser.dart` line 252-296):
```dart
/// GIB 좌표 시스템:
/// - YX 형식 (rank, file)
/// - 1-based 인덱싱 (files 1-9, ranks 1-10)
/// - 랭크는 한나라(Red) 쪽부터: rank 1 = 상단 (board rank 9)
///
/// 변환 공식:
/// - boardRank = 10 - gibRank
/// - boardFile = gibFile - 1

final gibFromRank = int.parse(coordMatch.group(1)!);  // 첫 번째 숫자 = rank
final gibFromFile = int.parse(coordMatch.group(2)!);  // 두 번째 숫자 = file

final fromRank = 10 - gibFromRank;  // GIB rank 1 (상단) = board rank 9
final fromFile = gibFromFile - 1;   // 1-based → 0-based
```

**검증**:
- 첫 수 "41漢兵42" (한나라 병 이동)
- From: GIB (4,1) → Board (6, 0) ✅
- To: GIB (4,2) → Board (6, 1) ✅

**디버그 스크립트**:
- `debug_gib_coordinates.dart`
- `verify_gib_fix.dart`

---

### 버그 #2: 퍼즐 턴 순서 오류 ✅

**발견 날짜**: 이전 세션
**심각도**: 🟡 High

**증상**:
퍼즐 시작 시 잘못된 플레이어 차례

**사용자 피드백**:
> "지금 내가 초를 움직이는데, 그 순서가 맞아?"

**원인**:
```dart
// 잘못된 로직
final currentPlayer = (_replayUpTo % 2 == 0)
    ? PieceColor.blue
    : PieceColor.red;
```

N개 수를 재생한 후의 다음 턴 계산이 잘못됨

**해결** (`lib/screens/puzzle_game_screen.dart` line 173-181):
```dart
// GIB 수 번호:
// 1, 3, 5, ... (홀수) = 한나라(Red)
// 2, 4, 6, ... (짝수) = 초나라(Blue)
// N개 수를 재생한 후, 다음 수는 (N+1)번째

final nextMoveNumber = _replayUpTo + 1;
final currentPlayer = (nextMoveNumber % 2 == 1)
    ? PieceColor.red   // 홀수 = 한나라
    : PieceColor.blue; // 짝수 = 초나라
```

**영향 범위**: 퍼즐 모드 전체

---

### 버그 #3: 조기 게임 종료 ✅

**발견 날짜**: 이전 세션
**심각도**: 🟡 High

**증상**:
퍼즐 로드 시 즉시 승리/패배 이미지 표시

**사용자 피드백**:
> "힌트를 누르면 이 이미지야. 이 이미지는 첫 프로그램 시작시 백그라운드 이미지인데"

**원인**:
- `setPuzzlePosition()` 내부에서 `_updateStatusMessage()` 호출
- `_updateStatusMessage()`가 체크메이트/스테일메이트 검사
- 묘수 위치가 이미 체크메이트 직전이라 게임 종료로 판정

**해결** (`lib/game/game_state.dart` line 279-287):
```dart
// setPuzzlePosition()에서 호출
void _setSimpleStatus() {
  // 체크메이트/스테일메이트 검사 없이 단순 턴 메시지만
  _statusMessage = '${_currentPlayer == PieceColor.blue ? "초 (Blue)" : "한 (Red)"} to move';

  // NOTE: _updateStatusMessage()를 호출하지 않음
  // 퍼즐 모드에서는 플레이어가 정답 수순을 완료해야만 게임 종료
}
```

**설계 원칙**:
- 퍼즐 모드: 정답 수순 완료 시에만 게임 종료
- 일반 게임: 체크메이트 즉시 게임 종료

---

### 버그 #4: Stockfish 미초기화 ✅

**발견 날짜**: 이전 세션
**심각도**: 🔴 Critical

**증상**:
```
Bad state: Stockfish not initialized
```
퍼즐 화면에서 힌트 버튼 클릭 시 에러

**원인**:
`puzzle_game_screen.dart`의 `initState()`에서 Stockfish 초기화 누락

**해결** (`lib/screens/puzzle_game_screen.dart` line 36-37):
```dart
@override
void initState() {
  super.initState();
  StockfishFFI.init(); // ✅ 추가
  _gameState = GameState(gameMode: GameMode.twoPlayer);
  // ...
}
```

**교훈**: 각 화면에서 Stockfish 사용 시 반드시 초기화 확인

---

### 버그 #5: AI 대전 "multipv" 파싱 버그 ✅

**발견 날짜**: 2026-01-12 (금일)
**심각도**: 🔴 Critical

**증상**:
```
flutter: StockfishFFI.getBestMove: Top moves: [1, 2, 3], Selected: 1
flutter: _getAIMove: Received best move: 1
flutter: _getAIMove: No valid move received from Stockfish
```

AI가 "e9f9" 같은 수 대신 숫자 "1", "2", "3"을 반환

**재현 방법**:
1. AI 대전 시작
2. 플레이어가 수를 둠
3. AI 차례가 되면 움직이지 않음

**원인 분석**:
```
info depth 10 multipv 1 score cp -276 ... pv e9f9 c1e4 ...
                   ↑ 'pv ' 첫 번째 매칭 (잘못!)
                                           ↑ 실제로 찾아야 할 위치
```

`line.indexOf('pv ')` 사용 시:
- `"multipv 1"`의 `"pv "`를 먼저 찾음
- 그 뒤의 `"1"`을 수로 파싱
- 결과: `[1, 2, 3]` (MultiPV 3개)

**해결** (`lib/stockfish_ffi.dart` line 177-195):
```dart
// 수정 전
if (line.contains('info') && line.contains('pv ')) {  // ❌
  final pvIndex = line.indexOf('pv ');
  final moveStart = pvIndex + 3;

// 수정 후
if (line.contains('info') && line.contains(' pv ')) {  // ✅ 공백 추가
  final pvIndex = line.indexOf(' pv ');
  if (pvIndex != -1) {
    final moveStart = pvIndex + 4;  // ' pv ' = 4글자
    // ...
  }
}
```

**추가 디버그 로그**:
```dart
debugPrint('StockfishFFI.getBestMove: Parsing PV line: "$line"');
debugPrint('StockfishFFI.getBestMove: Extracted move: "$move"');
```

**영향 범위**: AI 대전 전체 (모든 난이도)

**테스트 완료**:
- ✅ 쉬움 (depth 5)
- ✅ 보통 (depth 10)
- ✅ 어려움 (depth 15)

---

### 버그 #6: 고급 난이도 크래시 ✅

**발견 날짜**: 2026-01-12 (금일)
**심각도**: 🔴 Critical

**증상**:
```
[MOVE_PARSE] Applied 0 moves. Side to move: BLACK
Lost connection to device.
```

AI 대전 고급(depth 15)에서 앱 크래시

**재현 방법**:
1. AI 대전 고급 선택
2. 플레이어가 수를 둠
3. 앱 크래시

**시도한 해결책 (실패)**:

#### 시도 1: C++ stdout 캡처
**목적**: Stockfish info 라인을 받아서 역계산에 사용

**코드** (`engine/src/c_api.cpp`):
```cpp
else if (token == "go") {
    // stdout을 stringstream으로 리다이렉트
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

**실패 원인**:
1. **전역 변수 충돌**: `old_cout_streambuf` (line 29)가 이미 존재
2. **Thread-safety**: mutex 내부에서 stdout 리다이렉션 위험
3. **Depth 관련 문제**: depth가 높을수록 더 많은 info 라인 → 버퍼 문제
4. **Stockfish 내부 동작**: `handle_go()` 내부에서 직접 stdout 사용

**로그 분석**:
```
보통 (depth 10): 정상 작동 ✅
고급 (depth 15): 크래시 ❌

→ info 라인 개수와 관련
→ stdout 리다이렉션 중 버퍼 오버플로우 추정
```

**최종 해결**:
- C++ 수정 롤백
- `c_api.cpp`를 원래 상태로 복구
- DLL 재빌드
- AI 대전 정상 작동 확인

**빌드 커맨드**:
```bash
cd engine/src
g++ -O3 -std=c++17 -DNDEBUG -DIS_64BIT -DUSE_POPCNT \
    -DLARGEBOARDS -DNNUE_EMBEDDING_OFF -DPRECOMPUTED_MAGICS \
    -shared -fPIC -I. [모든 .cpp] \
    -o stockfish.dll -static-libgcc -static-libstdc++

cp stockfish.dll ../../windows/runner/
cp stockfish.dll ../../
```

**교훈**:
- C++ stdout 리다이렉션은 매우 위험
- 전역 상태와 충돌 가능성 높음
- 새로운 함수를 추가하는 것이 더 안전

---

## 📊 현재 상태

### ✅ 정상 작동하는 기능
1. **기본 게임 로직**
   - 9×10 장기판
   - 모든 기물 이동 규칙
   - 체크/체크메이트 감지
   - 4가지 초기 배치

2. **AI 대전**
   - 쉬움 (depth 5) ✅
   - 보통 (depth 10) ✅
   - 어려움 (depth 15) ✅
   - MultiPV 랜덤 수 선택 ✅

3. **AI 힌트**
   - 노란색 화살표로 최선의 수 표시
   - 퍼즐 모드에서도 사용 가능

4. **퍼즐 모드 UI**
   - GIB 파일 로드
   - 정답 수 검증
   - 오답 피드백
   - 승리 이미지 표시

### ⚠️ 제한적으로 작동
1. **퍼즐 전처리**
   - 70% fallback만 사용 가능
   - 역계산 알고리즘은 구현되어 있으나 실행 불가

### ❌ 미구현 기능
1. **역계산 기반 묘수 탐지**
   - Stockfish info 라인 접근 불가
   - C++ FFI 아키텍처 제약

---

## 🔴 미해결 이슈

### 이슈 #1: Stockfish Info 라인 접근 불가

**문제**:
현재 `stockfish_command()` 함수는 `bestmove`만 반환:
```cpp
// c_api.cpp
else if (token == "go") {
    handle_go(g_pos, is, g_states);
    Threads.main()->wait_for_search_finished();

    // bestmove만 cout_buffer에 저장
    cout_buffer << "bestmove " << moveStr << std::endl;
}
```

Stockfish의 info 라인 (`score cp`, `score mate` 등)은:
- ✅ 콘솔에 출력됨 (Flutter debugPrint로 확인 가능)
- ❌ 함수 반환값에 포함 안 됨

**영향**:
- 역계산 알고리즘이 position evaluation을 할 수 없음
- 묘수 시작점을 자동으로 찾을 수 없음
- 70% fallback에 의존

**가능한 해결 방안**:

#### 방안 A: 새로운 C++ 함수 추가 (추천) 🎯
```cpp
// c_api.cpp에 추가
__declspec(dllexport) const char* stockfish_analyze(const char* fen, int depth) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    // Position 설정
    std::istringstream fen_is(std::string("fen ") + fen);
    handle_position(g_pos, fen_is, g_states);

    // Go 실행
    std::istringstream go_is(std::string("depth ") + std::to_string(depth));
    handle_go(g_pos, go_is, g_states);
    Threads.main()->wait_for_search_finished();

    // Thread의 rootMoves에서 직접 평가값 추출
    Thread* mainThread = Threads.main();
    if (mainThread && !mainThread->rootMoves.empty()) {
        Value score = mainThread->rootMoves[0].score;

        // score를 문자열로 변환
        std::stringstream ss;
        if (score >= VALUE_MATE_IN_MAX_PLY) {
            int mate_in = (VALUE_MATE - score + 1) / 2;
            ss << "mate " << mate_in;
        } else if (score <= VALUE_MATED_IN_MAX_PLY) {
            int mate_in = (-VALUE_MATE - score) / 2;
            ss << "mate " << mate_in;
        } else {
            ss << "cp " << score;
        }

        // bestmove도 포함
        Move bestMove = mainThread->rootMoves[0].pv[0];
        ss << " bestmove " << UCI::move(g_pos, bestMove);

        // 출력 버퍼에 복사
        std::string output = ss.str();
        std::strncpy(output_buffer, output.c_str(), sizeof(output_buffer) - 1);
        return output_buffer;
    }

    return "error: no evaluation";
}
```

**Dart 바인딩**:
```dart
// stockfish_ffi.dart
typedef StockfishAnalyzeC = Pointer<Char> Function(Pointer<Char>, Int32);
typedef StockfishAnalyze = Pointer<Char> Function(Pointer<Char>, int);

static final StockfishAnalyze _stockfishAnalyze =
    _library.lookup<NativeFunction<StockfishAnalyzeC>>('stockfish_analyze').asFunction();

static Map<String, dynamic>? analyze(String fen, int depth) {
  final fenP = fen.toNativeUtf8();
  final resultP = _stockfishAnalyze(fenP.cast<Char>(), depth);
  final result = resultP.cast<Utf8>().toDartString();
  malloc.free(fenP);

  // "cp 300 bestmove e9f9" 또는 "mate 5 bestmove a1a2" 파싱
  final parts = result.split(' ');
  if (parts.length >= 2) {
    if (parts[0] == 'cp') {
      return {
        'type': 'cp',
        'value': int.parse(parts[1]),
        'bestmove': parts.length >= 4 ? parts[3] : null,
      };
    } else if (parts[0] == 'mate') {
      return {
        'type': 'mate',
        'value': int.parse(parts[1]),
        'bestmove': parts.length >= 4 ? parts[3] : null,
      };
    }
  }
  return null;
}
```

**장점**:
- ✅ 깔끔하고 안정적
- ✅ Thread 내부 데이터에 직접 접근
- ✅ stdout 리다이렉션 불필요
- ✅ 플랫폼 독립적

**단점**:
- ❌ C++ 코드 수정 필요
- ❌ DLL 재빌드 필요
- ❌ Stockfish 내부 구조 이해 필요

#### 방안 B: 70% Fallback 사용 (현재) 🟢
```dart
// gib_parser.dart
static Future<int> findPuzzleStartPosition(List<String> gibMoves, ...) async {
  // 역계산 시도...
  // 실패 시:
  return (totalMoves * 0.7).round().clamp(10, totalMoves - 5);
}
```

**장점**:
- ✅ 즉시 사용 가능
- ✅ 안정적
- ✅ 구현 간단

**단점**:
- ❌ 최적의 묘수 시작점 찾을 수 없음
- ❌ 퍼즐 품질 저하 가능

#### 방안 C: UCI 프로토콜 직접 구현 🔴
별도의 process로 Stockfish 실행, stdin/stdout으로 통신

**단점**:
- ❌ 매우 복잡
- ❌ 플랫폼별 구현 필요
- ❌ 성능 오버헤드

**권장 사항**: 방안 B (단기) → 방안 A (장기)

---

### 이슈 #2: 전처리 속도

**문제**:
- GIB 파일 2000+ 게임
- 각 게임당 20-30회 position evaluation (역계산)
- 총 40,000+ Stockfish 호출 예상
- 예상 소요 시간: 수 시간

**가능한 해결책**:
1. Depth 낮추기 (15 → 5)
2. 병렬 처리 (Isolate 사용)
3. 서버에서 전처리 후 JSON 제공

---

## 🔧 기술 노트

### GIB 좌표계
```
GIB 형식: YX (rank, file)
인덱싱: 1-based
랭크 방향: 한나라(Red)부터 (rank 1 = 상단)

예시: "41漢兵42"
- From: (rank=4, file=1)
- To: (rank=4, file=2)

변환:
- boardRank = 10 - gibRank
- boardFile = gibFile - 1

결과:
- From: (6, 0)
- To: (6, 1)
```

### Stockfish FEN 좌표계
```
FEN은 rank 10 (상단)부터 rank 1 (하단)까지
Flutter board는 rank 0 (하단)부터 rank 9 (상단)까지

변환:
- stockfishRank = 10 - flutterRank
```

### MultiPV 파싱
```
❌ 잘못된 방법:
line.indexOf('pv ')  → "multipv 1"의 "pv "를 매칭

✅ 올바른 방법:
line.indexOf(' pv ') → 실제 수 리스트의 " pv "만 매칭
```

### C++ stdout 리다이렉션 문제
```cpp
// ❌ 작동하지 않음
std::stringstream buffer;
std::cout.rdbuf(buffer.rdbuf());  // 전역 old_cout_streambuf와 충돌

// ✅ 대안: Thread의 rootMoves에서 직접 추출
Thread* t = Threads.main();
Value score = t->rootMoves[0].score;
```

---

## 📝 다음 단계

### 우선순위 1: 퍼즐 모드 안정화
- [x] GIB 파싱 버그 수정
- [x] 턴 순서 수정
- [x] 조기 종료 버그 수정
- [ ] 70% fallback으로 퍼즐 생성
- [ ] JSON 저장 및 로드 테스트
- [ ] 사용자 테스트

### 우선순위 2: AI 대전 개선
- [x] MultiPV 파싱 버그 수정
- [x] 모든 난이도 안정화
- [ ] 승리/패배 사운드 추가
- [ ] AI 사고 시간 표시

### 우선순위 3: 역계산 구현 (선택)
- [ ] C++에 `stockfish_analyze()` 함수 추가
- [ ] Dart FFI 바인딩
- [ ] 역계산 알고리즘 테스트
- [ ] 전체 GIB 파일 전처리

### 우선순위 4: 기타 개선
- [ ] 효과음 추가
- [ ] 배경 음악
- [ ] 통계 화면
- [ ] 설정 화면

---

## 🎓 배운 점

### 1. 좌표계 변환의 중요성
- GIB, Flutter Board, Stockfish FEN 각각 다른 좌표계
- 첫 수를 항상 검증하여 좌표 변환 확인
- 문서화와 주석이 매우 중요

### 2. FFI의 한계
- C++ stdout을 Dart로 캡처하기 어려움
- Thread-safety 문제 주의
- 새로운 함수를 추가하는 것이 안전

### 3. 디버깅 전략
- 로그를 먼저 보고 가설 수립
- 간단한 테스트 케이스로 검증
- 한 번에 하나씩 수정

### 4. Fallback의 가치
- 완벽한 해결책을 기다리는 것보다
- 동작하는 간단한 해결책이 더 나을 수 있음
- 70% fallback도 충분히 유용

### 5. 문자열 파싱의 함정
- `indexOf('pv ')` vs `indexOf(' pv ')`
- 작은 차이가 큰 버그를 만듦
- 엣지 케이스 철저히 테스트

---

## 📚 참고 자료

### 코드 파일
- `lib/utils/gib_parser.dart` - GIB 파싱 및 역계산
- `lib/screens/puzzle_game_screen.dart` - 퍼즐 UI
- `lib/stockfish_ffi.dart` - Stockfish FFI 바인딩
- `engine/src/c_api.cpp` - C++ FFI wrapper

### 문서
- [FEATURES.md](FEATURES.md) - 구현된 기능 목록
- [TESTING.md](TESTING.md) - 테스트 가이드
- [GIB Format](https://www.example.com) - GIB 형식 설명

### 디버그 스크립트
- `debug_gib_coordinates.dart` - 좌표 변환 테스트
- `verify_gib_fix.dart` - GIB 파싱 검증
- `test_puzzle_extraction.dart` - 퍼즐 추출 테스트

---

**작성**: Claude Sonnet 4.5
**검토**: User
**버전**: 1.0.0
**최종 업데이트**: 2026-01-12
