# GIB Corpus Pipeline

이 프로젝트는 raw GIB 원본을 저장소에 넣지 않고, 리포 밖 코퍼스 루트를 기준으로
`수집 -> 정규화 -> 후보 추출 -> 기존 검증기 연결` 흐름으로 운용한다.

## 코퍼스 루트

- 환경 변수: `JANGGI_GIB_ROOT`
- 기본 경로: `%USERPROFILE%\\Documents\\janggi_gib_corpus`

코퍼스 루트 구조:

```text
<root>/
  raw/
    kja_pds/
  manual_drop/
  manifests/
  normalized/
```

## 1. 대한장기협회 자료실 수집

```powershell
dart run tool/import_gib_corpus.dart --source kja_pds --pages 1
```

선택 옵션:

- `--root <path>`: 코퍼스 루트 override
- `--pages <n>`: 스캔할 페이지 수
- `--since-id <n>`: 지정 ID 이하 게시물 건너뛰기

## 2. 수동 드롭 폴더 수집

사용자가 직접 구한 `GIB` 또는 `plain text move list` 파일을
`manual_drop/` 폴더에 넣은 뒤 아래 명령으로 정규화한다.

```powershell
dart run tool/import_gib_corpus.dart --source manual_drop
```

선택 옵션:

- `--root <path>`
- `--manual-dir <path>`

지원 포맷:

- `.gib`
- `.txt`
- `.gib.txt`

plain text 포맷은 `1. ... 2. ...` 형태의 numbered move list만 지원한다.

## 3. 퍼즐 후보 추출

```powershell
dart run tool/extract_puzzle_candidates.dart --output test_tmp/puzzle_candidates.json
```

선택 옵션:

- `--root <path>`
- `--input <normalized file|directory|wildcard>`
- `--output <path>`
- `--limit-games <n>`

출력 파일은 기존 `tool/puzzle_quality_validator.dart` 입력 형식과 호환된다.

## 4. 기존 검증기 연결

```powershell
dart run tool/puzzle_quality_validator.dart ^
  --input test_tmp/puzzle_candidates.json ^
  --report test_tmp/puzzle_candidate_report.json ^
  --strict-output test_tmp/puzzle_candidate_strict.json ^
  --engine engine/src/stockfish.exe
```

## 운영 원칙

- raw GIB와 full normalized corpus는 리포에 커밋하지 않는다.
- 저장소에는 추출 결과, 리포트, 검증 스크립트만 반영한다.
- 대한장기협회 자료실 원본은 내부 연구/추출용으로만 사용하고 raw 재배포는 하지 않는다.
