# 스킵 로직 검증 파일 - 2026-02-11 (00:21)

## 개요
이 파일은 에이전트가 불필요한 데이터를 "스킵"하고 핵심적인 부분만 처리할 수 있는지 검증하기 위한 더미 데이터를 포함합니다.

## 더미 섹션 A (무시해야 함)
IGNORE_THIS_START
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
IGNORE_THIS_END

## 핵심 섹션 (중요)
CRITICAL_DATA_START
{
  "target": "verify_skip_logic",
  "status": "success",
  "message": "This section must be processed."
}
CRITICAL_DATA_END

## 더미 섹션 B (무시해야 함)
IGNORE_THIS_START
Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.
IGNORE_THIS_END
