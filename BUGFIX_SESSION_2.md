# 버그 수정 세션 #2 - 2026-01-12

## 수정된 버그 목록

### 1. 장군 애니메이션 타이밍 문제 ⏱️

**문제**:
- 장군 애니메이션이 플레이어가 움직인 직후 나타나지 않고, AI가 생각한 후에 나타남
- 원래는 50ms 딜레이만 있었음

**원인**:
- AI 턴 시작 전 딜레이가 모든 경우에 동일하게 짧았음
- 장군 상황에서 사용자가 알림을 보기 전에 AI가 바로 움직임

**해결**:
```dart
// _makeMove 함수에서 AI 턴 시작 전 조건부 딜레이 추가
final delayMs = _isInCheck ? 1000 : 300;
await Future.delayed(Duration(milliseconds: delayMs));
```

**결과**:
- ✅ 장군 상황: 1000ms 대기 → 알림을 확실히 볼 수 있음
- ✅ 일반 상황: 300ms 대기 → 빠른 게임 진행

---

### 2. 차(車) 궁성 대각선 이동 제한 문제 🚗

**문제**:
- 차가 궁성 내에서 대각선으로 1칸만 이동 가능
- 코너에서 반대 코너로 이동 불가 (예: d0 → f2)
- 장기 규칙: 차는 대각선이 연결되어 있으면 여러 칸 이동 가능

**오해했던 규칙**:
- ❌ 잘못 이해: "차는 궁성에서 대각선 1칸만 가능 (사처럼)"
- ✅ 올바른 규칙: "차는 궁성 대각선을 따라 여러 칸 이동 가능"

**해결**:
1. `_isValidPalaceDiagonalMove()` 함수 추가:
   - 코너 → 중앙 (1칸)
   - 중앙 → 코너 (1칸)
   - 코너 → 반대 코너 (2칸, 중앙을 통과)

2. `_isValidMove()`와 `_isValidMoveOnBoard()` 모두 업데이트:
   ```dart
   if (_isValidPalaceDiagonalMove(from, to, piece.color == PieceColor.red)) {
     return _isPalaceDiagonalPathClear(from, to, piece.color == PieceColor.red);
   }
   ```

**결과**:
- ✅ 차가 d0 → e1 → f2 경로로 이동 가능
- ✅ 모든 궁성 대각선 경로 지원

---

### 3. 차가 왕을 위협할 때 장군 알림 안 뜨는 문제 ⚠️🐛

**문제 상황**:
```
상황: 청 차가 홍 궁성에 침투
- 청 차 위치: d9 (홍 궁성 왼쪽 위 코너)
- 홍 장군 위치: e8 (홍 궁성 중앙)
- 차가 사(士)를 잡으면 → 장군이 장군 상태
- 하지만 장군 알림이 안 뜸!
```

**로그 분석**:
```
_isKingInCheck: Checking if red king at e8 is in check
_isKingInCheck: No threats found to red king  ← 문제!
```

**원인 (핵심)**:
```dart
// 이전 코드 (틀림)
if (from.isInPalace(isRedPalace: piece.color == PieceColor.red) &&
    to.isInPalace(isRedPalace: piece.color == PieceColor.red))
```

- `piece.color == PieceColor.red` → **차의 색깔**로 궁성 판단
- 청 차(blue)가 홍 궁성(red palace)에 있어도
- `isRedPalace: false`로 체크 → **청 궁성 기준**으로 대각선 검증
- 결과: 홍 궁성의 대각선 경로(d9→e8)를 유효하지 않다고 판단

**실제 좌표**:
- d9 = (3, 9) = 홍 궁성 왼쪽 위 코너 ✓
- e8 = (4, 8) = 홍 궁성 중앙 ✓
- 청 궁성 기준으로 체크하니까 대각선 인식 실패 ✗

**해결**:
```dart
// 수정된 코드 (맞음)
// IMPORTANT: Check ACTUAL palace location, not piece color
// A blue chariot can be in red palace and vice versa
final inBluePalace = from.isInPalace(isRedPalace: false) &&
                     to.isInPalace(isRedPalace: false);
final inRedPalace = from.isInPalace(isRedPalace: true) &&
                    to.isInPalace(isRedPalace: true);

if (inBluePalace) {
  if (_isValidPalaceDiagonalMove(from, to, false)) {
    return _isPalaceDiagonalPathClearOnBoard(from, to, false, board);
  }
} else if (inRedPalace) {
  if (_isValidPalaceDiagonalMove(from, to, true)) {
    return _isPalaceDiagonalPathClearOnBoard(from, to, true, board);
  }
}
```

**핵심 변경점**:
- ❌ 이전: 기물 색깔(`piece.color`)로 궁성 판단
- ✅ 이후: **실제 위치**(`from`/`to`의 좌표)로 궁성 판단

**결과**:
- ✅ 청 차가 홍 궁성에서 홍 장군 위협 → 장군 알림 표시
- ✅ 홍 차가 청 궁성에서 청 장군 위협 → 장군 알림 표시
- ✅ 모든 궁성 침투 시나리오에서 정확한 장군 감지

---

## 디버깅 개선사항

### 추가된 로그
```dart
// _isKingInCheck 함수에 디버그 로그 추가
debugPrint('_isKingInCheck: Checking if ${kingColor.name} king at $kingPosition is in check');
debugPrint('_isKingInCheck: YES! ${piece.color.name} ${piece.type.name} at $pos can attack king');
debugPrint('_isKingInCheck: No threats found to ${kingColor.name} king');
```

**효과**:
- 장군 체크 과정을 실시간으로 추적 가능
- 어떤 기물이 왕을 위협하는지 즉시 확인
- 버그 발견 시간 단축

---

## 수정된 파일

### `janggi_master/lib/game/game_state.dart`

**변경 사항**:
1. `_makeMove()`: AI 턴 시작 전 조건부 딜레이 (라인 463-474)
2. `_isValidPalaceDiagonalMove()`: 새로운 함수 추가 (라인 973-1025)
3. `_isValidMove()`: 차 대각선 이동 검증 업데이트 (라인 711-718)
4. `_isValidMoveOnBoard()`: 차 대각선 이동 - 실제 궁성 위치 기반 체크 (라인 1242-1261)
5. `_isKingInCheck()`: 디버그 로그 추가 (라인 1105-1155)

**총 변경**: +319줄, -12줄

---

## 학습한 장기 규칙

### 차(車)의 궁성 대각선 이동
- ✅ 차는 궁성 대각선을 **여러 칸** 이동 가능
- ✅ 코너 → 중앙 → 반대 코너 경로 지원
- ❌ 사(士)나 장(將)처럼 1칸만 가능한 것이 아님

### 기물의 궁성 구분
- 기물은 **자기 색깔 궁성**에만 머무는 것이 아님
- 상대방 궁성에 침투 가능
- 침투 시 **실제 위치한 궁성**의 규칙을 따름

---

## 테스트 시나리오

### 시나리오 1: 차 궁성 대각선 이동
```
1. 청 차를 d0에 배치
2. 차 선택 → 유효한 이동: e1, f2 확인
3. d0 → f2 이동 (2칸 대각선) → ✅ 성공
```

### 시나리오 2: 궁성 침투 후 장군
```
1. 청 차가 홍 궁성으로 침투 (예: d9)
2. 홍 사를 잡음 (e8 → d9)
3. 장군 알림 표시 확인 → ✅ "장군!" 표시
```

### 시나리오 3: 장군 애니메이션 타이밍
```
1. 플레이어가 상대를 장군 상태로 만드는 수 둠
2. "장군!" 알림 즉시 표시 → ✅ 1초간 표시
3. AI가 응수 → ✅ 알림 본 후 AI 시작
```

---

## 커밋 정보

**Commit**: `dac23a5`
**Message**: `fix: Chariot palace diagonal check detection bug`
**Date**: 2026-01-12
**Files Changed**: 1 (game_state.dart)

---

## 다음 작업 예정

- [ ] 포(砲)의 궁성 대각선 이동도 같은 방식으로 수정 필요 확인
- [ ] 모든 기물 타입의 궁성 이동 검증 테스트
- [ ] 체크메이트 시나리오 테스트
- [ ] 퍼즐 모드에서 장군 감지 테스트

---

**작성일**: 2026-01-12
**수정자**: Claude Sonnet 4.5
