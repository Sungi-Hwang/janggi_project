# 퍼즐 자동화 매뉴얼

## 목적
- 새 기보를 받을 때마다 퍼즐을 수동으로 다시 만들지 않도록, `기보 -> 후보 추출 -> 엔진 검증 -> 카탈로그 반영` 흐름을 반복 가능한 작업으로 고정한다.
- 기본 퍼즐 세트는 항상 `Strict`만 노출한다.
- `Relaxed`와 `Quarantine`은 별도 보관하여 이후 재활용하거나 재검증한다.

## 현재 기준 정의
- `Strict`: 유일 정답이고, 상대의 최선 방어에도 최단 수로 외통이 나는 퍼즐
- `Relaxed`: 외통은 성립하지만 첫 수가 여러 개이거나, 실전 감상용 가치가 큰 퍼즐
- `Quarantine`: 엔진 검증에 실패했거나, timeout 등으로 판정이 불안정한 퍼즐

## 현재 저장 위치
- 기본 퍼즐 세트: [assets/puzzles/puzzles.json](/D:/Project/janggi-master/janggi_master/assets/puzzles/puzzles.json)
- relaxed 세트: [assets/puzzles/puzzles_relaxed.json](/D:/Project/janggi-master/janggi_master/assets/puzzles/puzzles_relaxed.json)
- quarantine 세트: [assets/puzzles/puzzles_quarantine.json](/D:/Project/janggi-master/janggi_master/assets/puzzles/puzzles_quarantine.json)
- 퍼즐 검증기: [tool/puzzle_quality_validator.dart](/D:/Project/janggi-master/janggi_master/tool/puzzle_quality_validator.dart)
- 세트 분리기: [tool/split_puzzle_catalog.dart](/D:/Project/janggi-master/janggi_master/tool/split_puzzle_catalog.dart)
- 무결성 테스트: [test/puzzle_catalog_integrity_test.dart](/D:/Project/janggi-master/janggi_master/test/puzzle_catalog_integrity_test.dart)
- 이전 기획 문서: [docs/puzzle_growth_strategy.md](/D:/Project/janggi-master/janggi_master/docs/puzzle_growth_strategy.md)

## 현재 베타 기준 수량
- strict: 246개
- relaxed: 36개
- quarantine: 10개

## 작업 전 원칙
- 앱 기본 퍼즐은 반드시 `Strict`만 사용한다.
- 자동 검증에 실패한 퍼즐은 기본 세트에 다시 넣지 않는다.
- 새 기보를 추가하기 전, 기존 퍼즐 파일은 백업한다.
- 빠른 1차 필터와 느린 2차 검증을 분리해서 돌린다.

## 추천 폴더 규칙
- 새 기보 원본은 `data/gib/` 아래에 모은다.
- 실험 결과물은 `dev/test_tmp/` 아래에 둔다.
- 최종 배포용 퍼즐만 `assets/puzzles/`에 반영한다.

예시 구조:

```text
data/
  gib/
    kakao/
    janggidosa/
    manual/
dev/test_tmp/
assets/
  puzzles/
```

## 1. 엔진 준비
- Windows 기준 검증기는 `engine/src/stockfish.exe`를 우선 사용한다.
- 실행 파일이 없으면 먼저 빌드한다.

예시:

```powershell
cd D:\Project\janggi-master\janggi_master\engine\src
mingw32-make build COMP=mingw ARCH=x86-64-modern largeboards=yes all=yes nnue=no -j4
```

빌드 후 확인할 파일:
- [engine/src/stockfish.exe](/D:/Project/janggi-master/janggi_master/engine/src/stockfish.exe)

## 2. 기보 후보 추출
- 아직 이 단계는 완전히 구현되지 않았다.
- 다음 구현 목표는 `tool/extract_puzzle_candidates.dart`를 만들어 `.gib` 전체에서 후보 포지션을 자동 추출하는 것이다.

추출기의 목표:
- 모든 `.gib` 파일을 순회한다.
- 각 대국의 모든 ply를 본다.
- `mate in 1~3`, 평가 급변, 유일수 가능성을 메타데이터로 함께 저장한다.

추출기 출력 예시:
- `dev/test_tmp/puzzle_candidates.json`

후보 한 건에 들어가야 할 메타데이터 예시:
- `sourceFile`
- `gameIndex`
- `moveIndex`
- `fen`
- `toMove`
- `bestMove`
- `mateIn`
- `evalSwing`

## 3. 1차 자동 검증
- 대량 후보를 빠르게 걸러내는 단계다.
- 추천 설정은 `depth=8`, `multipv=3`이다.

예시:

```powershell
cd D:\Project\janggi-master\janggi_master
dart run tool/puzzle_quality_validator.dart ^
  --input dev/test_tmp/puzzle_candidates.json ^
  --report dev/test_tmp/puzzle_quality_validation_fast.json ^
  --strict-output dev/test_tmp/puzzles_strict_preview_fast.json ^
  --depth 8 ^
  --multipv 3 ^
  --engine engine/src/stockfish.exe
```

이 단계의 목적:
- strict 후보를 빠르게 찾는다.
- relaxed 후보를 따로 분리할 근거를 만든다.
- timeout, 유일 정답 불명, 시작부터 강제 외통 아님 같은 실패 사유를 기록한다.

## 4. 2차 정밀 검증
- 느리지만 중요한 퍼즐만 다시 깊게 본다.
- 대상:
  - `mate in 2`
  - `mate in 3`
  - timeout 난 퍼즐
  - relaxed 중 살릴 가치가 큰 퍼즐

예시:

```powershell
cd D:\Project\janggi-master\janggi_master
dart run tool/puzzle_quality_validator.dart ^
  --input dev/test_tmp/borderline_candidates.json ^
  --report dev/test_tmp/puzzle_quality_validation_deep.json ^
  --strict-output dev/test_tmp/puzzles_strict_preview_deep.json ^
  --depth 12 ^
  --multipv 6 ^
  --engine engine/src/stockfish.exe
```

## 5. strict / relaxed / quarantine 분리
- 검증 리포트를 기준으로 카탈로그를 나눈다.
- 현재 이 단계는 이미 구현되어 있다.

예시:

```powershell
cd D:\Project\janggi-master\janggi_master
dart run tool/split_puzzle_catalog.dart ^
  --input dev/test_tmp/puzzle_candidates.json ^
  --report dev/test_tmp/puzzle_quality_validation_fast.json ^
  --strict-output assets/puzzles/puzzles.json ^
  --relaxed-output assets/puzzles/puzzles_relaxed.json ^
  --quarantine-output assets/puzzles/puzzles_quarantine.json
```

주의:
- `--replace-input`은 원본 파일을 strict 세트로 덮어쓴다.
- 원본 보존이 필요하면 먼저 백업한 뒤 사용한다.

## 6. 배포 전 검증
- 카탈로그를 만든 뒤에는 테스트를 반드시 다시 돌린다.

예시:

```powershell
cd D:\Project\janggi-master\janggi_master
flutter test -r compact test/widget_test.dart test/game_state_stability_test.dart test/puzzle_catalog_integrity_test.dart
```

확인해야 할 것:
- 퍼즐 총 수와 카테고리 수가 맞는지
- strict 퍼즐에 `validation` 정보가 남아 있는지
- 앱 실행 시 퍼즐 목록과 상세 진입이 정상인지

## 7. 운영 체크리스트
- 새 `.gib` 파일을 `data/gib/`에 넣었는가
- 기존 `assets/puzzles/puzzles.json`을 백업했는가
- 1차 빠른 검증을 돌렸는가
- `mate in 2/3`와 timeout 퍼즐에 대해 2차 검증을 돌렸는가
- strict/relaxed/quarantine 분리를 완료했는가
- 테스트를 다시 돌렸는가
- 변경된 퍼즐 수량을 기록했는가

## 8. 퍼즐 흥미도 운영 규칙
- 기본 탭은 strict만 사용한다.
- `오늘의 문제`는 `mate in 1` 또는 `유일수` 우선으로 고른다.
- relaxed는 `실전 명장면`, `복수 정답 허용` 같은 별도 기획에서만 사용한다.
- quarantine은 다시 기본 세트에 넣지 않는다.

## 9. 다음 구현 우선순위
1. `tool/extract_puzzle_candidates.dart`
- `.gib` 전체 스캔 자동화
- 모든 ply 후보 추출

2. `tool/rank_and_dedupe_puzzles.dart`
- 같은 FEN 제거
- 비슷한 문제 정리
- 품질 점수 계산

3. `tool/build_puzzle_release.dart`
- 추출, 검증, 분리, 테스트, 통계 출력까지 한 번에 실행

목표 명령어:

```powershell
dart run tool/build_puzzle_release.dart --source data/gib --engine engine/src/stockfish.exe
```

## 10. 다음에 다시 시작할 때 바로 볼 것
- 이 문서: [docs/puzzle_automation_manual.md](/D:/Project/janggi-master/janggi_master/docs/puzzle_automation_manual.md)
- 전략 문서: [docs/puzzle_growth_strategy.md](/D:/Project/janggi-master/janggi_master/docs/puzzle_growth_strategy.md)
- 최신 검증 리포트: [dev/test_tmp/puzzle_quality_validation_full_d8_m3.json](/D:/Project/janggi-master/janggi_master/dev/test_tmp/puzzle_quality_validation_full_d8_m3.json)
- strict 교체 전 백업: [dev/test_tmp/puzzles_before_strict_replace.json](/D:/Project/janggi-master/janggi_master/dev/test_tmp/puzzles_before_strict_replace.json)

## 11. 메모
- 현재 카카오 기보 폴더는 사실상 전수 스캔을 마친 상태다.
- 새 퍼즐을 크게 늘리려면 새 `.gib` 원본 확보 또는 추출기 고도화가 필요하다.
- 명국집, 대회 VOD, 장기도사 export는 다음 소스 후보로 유지한다.

## 12. 실험 기록

### 2026-03-21 self-play 추출 실험
- 실험 스크립트: [generate_selfplay_puzzles.dart](/D:/Project/janggi-master/janggi_master/tool/generate_selfplay_puzzles.dart)
- 출력 파일: [selfplay_puzzles_10.json](/D:/Project/janggi-master/janggi_master/dev/test_tmp/selfplay_puzzles_10.json)
- 검증 리포트: [selfplay_puzzles_10_validation.json](/D:/Project/janggi-master/janggi_master/dev/test_tmp/selfplay_puzzles_10_validation.json)

실험 내용:
- 표준 시작 포지션 self-play
- 축소 endgame seed self-play
- 종반 포지션 스캔
- 합법 첫 수 전술 탐지

결과:
- 추출 퍼즐 `0개`
- strict 검증 통과 `0개`

해석:
- `자가대국만으로 1~3수 외통을 바로 대량 생산하는 방식`은 효율이 낮다.
- 장기 퍼즐 소스는 여전히 `실전 기보`, `명국`, `반자동 입력`, `전술 탐지기`가 더 유망하다.
- self-play는 장기적으로 보조 소스나 특수 endgame seed 실험용으로 유지하는 편이 맞다.
