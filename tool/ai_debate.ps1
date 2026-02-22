param(
  [string]$Topic = "",
  [string]$Request = "",
  [string]$Channel = "discord",
  [string]$To = "channel:1467904167921324184",
  [string]$Thinking = "low",
  [int]$StepTimeoutSec = 120,
  [int]$SynthesisTimeoutSec = 90,
  [int]$SynthesisMaxChars = 1400,
  [int]$RetryCount = 1,
  [int]$RetryDelaySec = 3,
  [bool]$ShowProgress = $true,
  [ValidateSet("local-first", "model-first")]
  [string]$SynthesisMode = "model-first"
)
$ErrorActionPreference = "Stop"
$OpenClawCmd = "C:\Users\PC\AppData\Roaming\npm\openclaw.cmd"
if (-not (Test-Path $OpenClawCmd)) { $OpenClawCmd = "openclaw" }

# Prevent mojibake in Windows shell contexts.
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
try { chcp 65001 | Out-Null } catch {}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runDir = Join-Path "d:\Project\janggi-master\tool\debate-runs" $stamp
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$timelinePath = Join-Path $runDir "timeline.log"

function Save-Text {
  param(
    [string]$Path,
    [string]$Text
  )
  Set-Content -Path $Path -Value $Text -Encoding UTF8
}

function Save-Json {
  param(
    [string]$Path,
    [object]$Obj
  )
  $Obj | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

function Write-ProgressLog {
  param(
    [string]$Message,
    [string]$Level = "INFO"
  )
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
  Add-Content -Path $timelinePath -Value $line -Encoding UTF8
  if ($ShowProgress) { Write-Host $line }
}

function Clip-Text {
  param([string]$Text, [int]$Max = 120)
  if ([string]::IsNullOrEmpty($Text)) { return "" }
  $t = $Text.Replace("`r", " ").Replace("`n", " ").Trim()
  if ($t.Length -le $Max) { return $t }
  return ($t.Substring(0, $Max) + "...")
}

function Normalize-ForSynthesis {
  param(
    [string]$Text,
    [int]$MaxChars = 1400
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  $t = $Text.Replace("`r", "")
  $t = [regex]::Replace($t, '```[\s\S]*?```', '')
  $t = [regex]::Replace($t, '[`*_#>-]', '')
  $t = [regex]::Replace($t, '\s+', ' ').Trim()
  if ($t.Length -gt $MaxChars) { $t = $t.Substring(0, $MaxChars) + "..." }
  return $t
}

function Resolve-Topic {
  param(
    [string]$TopicText,
    [string]$RequestText
  )
  if (-not [string]::IsNullOrWhiteSpace($TopicText)) { return $TopicText.Trim() }
  if ([string]::IsNullOrWhiteSpace($RequestText)) { return "" }

  $req = $RequestText.Trim()
  $patterns = @(
    '^\s*(.+?)\s*에\s*대해\s*토론해(?:봐|보자|줘)?\s*$',
    '^\s*(.+?)\s*토론해(?:봐|보자|줘)?\s*$',
    '^\s*토론\s*주제\s*:\s*(.+?)\s*$'
  )
  foreach ($p in $patterns) {
    $m = [regex]::Match($req, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success -and $m.Groups.Count -ge 2) {
      $candidate = $m.Groups[1].Value.Trim(' ', '"', "'", "`t", "`r", "`n")
      if (-not [string]::IsNullOrWhiteSpace($candidate)) { return $candidate }
    }
  }
  return $req
}

function Convert-RawToResult {
  param(
    [string]$AgentId,
    [string]$StepName,
    [datetime]$Start,
    [datetime]$End,
    [string]$RawText,
    [bool]$TimedOut,
    [string]$StepDir
  )

  Save-Text -Path (Join-Path $StepDir "raw_output.txt") -Text $RawText

  if ([string]::IsNullOrWhiteSpace($RawText)) {
    $empty = [pscustomobject]@{
      agent = $AgentId
      step = $StepName
      elapsedSec = [math]::Round(($End - $Start).TotalSeconds, 2)
      text = if ($TimedOut) { "(timeout after $StepTimeoutSec sec, retries: $RetryCount)" } else { "(empty response)" }
      usage = $null
      parse = if ($TimedOut) { "timeout" } else { "empty" }
    }
    Save-Text -Path (Join-Path $StepDir "answer.txt") -Text $empty.text
    Save-Json -Path (Join-Path $StepDir "result.json") -Obj $empty
    Write-ProgressLog -Level "WARN" -Message ("{0} done: parse={1}, elapsed={2}s" -f $StepName, $empty.parse, $empty.elapsedSec)
    return $empty
  }

  $obj = $null
  $jsonMatch = [regex]::Match($RawText, '(?s)\{.*\}\s*$')
  if ($jsonMatch.Success) {
    try { $obj = $jsonMatch.Value | ConvertFrom-Json } catch { $obj = $null }
  }

  if (-not $obj) {
    $fallback = [pscustomobject]@{
      agent = $AgentId
      step = $StepName
      elapsedSec = [math]::Round(($End - $Start).TotalSeconds, 2)
      text = $RawText
      usage = $null
      parse = "plain_text"
    }
    Save-Text -Path (Join-Path $StepDir "answer.txt") -Text $RawText
    Save-Json -Path (Join-Path $StepDir "result.json") -Obj $fallback
    Write-ProgressLog -Message ("{0} done: parse={1}, elapsed={2}s, preview={3}" -f $StepName, $fallback.parse, $fallback.elapsedSec, (Clip-Text -Text $fallback.text))
    return $fallback
  }

  $text = $obj.result.payloads[0].text
  if (-not $text) { $text = "(no text payload)" }

  $result = [pscustomobject]@{
    agent = $AgentId
    step = $StepName
    elapsedSec = [math]::Round(($End - $Start).TotalSeconds, 2)
    text = $text
    usage = $obj.result.meta.agentMeta.usage
    parse = "ok"
  }

  Save-Text -Path (Join-Path $StepDir "answer.txt") -Text $text
  Save-Json -Path (Join-Path $StepDir "result.json") -Obj $result
  Write-ProgressLog -Message ("{0} done: parse={1}, elapsed={2}s, preview={3}" -f $StepName, $result.parse, $result.elapsedSec, (Clip-Text -Text $result.text))
  return $result
}

function Invoke-AgentTurn {
  param(
    [string]$AgentId,
    [string]$Prompt,
    [string]$StepName,
    [int]$TimeoutSec = 0
  )

  $effectiveTimeout = if ($TimeoutSec -gt 0) { $TimeoutSec } else { $StepTimeoutSec }

  $stepDir = Join-Path $runDir $StepName
  New-Item -ItemType Directory -Path $stepDir -Force | Out-Null
  Save-Text -Path (Join-Path $stepDir "prompt.txt") -Text $Prompt
  Write-ProgressLog -Message ("{0} start (agent={1}, timeout={2}s)" -f $StepName, $AgentId, $effectiveTimeout)

  $start = Get-Date
  $rawText = ""
  $timedOut = $false

  for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
    $job = Start-Job -ScriptBlock {
      param($cmd, $agent, $channel, $to, $msg, $thinking)
      [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
      [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      try { chcp 65001 | Out-Null } catch {}
      & $cmd --no-color agent --agent $agent --channel $channel --to $to --message $msg --thinking $thinking --json 2>&1 | Out-String
    } -ArgumentList $OpenClawCmd, $AgentId, $Channel, $To, $Prompt, $Thinking

    $done = Wait-Job -Job $job -Timeout $effectiveTimeout
    if (-not $done) {
      $timedOut = $true
      Stop-Job -Job $job | Out-Null
      Remove-Job -Job $job | Out-Null
      if ($attempt -lt $RetryCount) { Start-Sleep -Seconds $RetryDelaySec }
      continue
    }

    $rawText = (Receive-Job -Job $job | Out-String).Trim()
    Remove-Job -Job $job | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($rawText)) { break }
    if ($attempt -lt $RetryCount) { Start-Sleep -Seconds $RetryDelaySec }
  }

  $end = Get-Date
  return Convert-RawToResult -AgentId $AgentId -StepName $StepName -Start $start -End $end -RawText $rawText -TimedOut $timedOut -StepDir $stepDir
}

function Invoke-AgentTurnsParallel {
  param(
    [array]$Turns,
    [int]$TimeoutSec = 0
  )

  $effectiveTimeout = if ($TimeoutSec -gt 0) { $TimeoutSec } else { $StepTimeoutSec }

  $metas = @()
  $names = ($Turns | ForEach-Object { $_.StepName }) -join ", "
  Write-ProgressLog -Message ("parallel start: {0} (timeout={1}s)" -f $names, $effectiveTimeout)

  foreach ($turn in $Turns) {
    $stepDir = Join-Path $runDir $turn.StepName
    New-Item -ItemType Directory -Path $stepDir -Force | Out-Null
    Save-Text -Path (Join-Path $stepDir "prompt.txt") -Text $turn.Prompt

    $job = Start-Job -ScriptBlock {
      param($cmd, $agent, $channel, $to, $msg, $thinking)
      [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
      [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
      try { chcp 65001 | Out-Null } catch {}
      & $cmd --no-color agent --agent $agent --channel $channel --to $to --message $msg --thinking $thinking --json 2>&1 | Out-String
    } -ArgumentList $OpenClawCmd, $turn.AgentId, $Channel, $To, $turn.Prompt, $Thinking

    $metas += [pscustomobject]@{
      AgentId = $turn.AgentId
      StepName = $turn.StepName
      StepDir = $stepDir
      Job = $job
      Start = Get-Date
    }
  }

  Wait-Job -Job ($metas.Job) -Timeout $effectiveTimeout | Out-Null

  $results = @{}
  foreach ($m in $metas) {
    $timedOut = $false
    $rawText = ""

    if ($m.Job.State -eq "Running" -or $m.Job.State -eq "NotStarted") {
      $timedOut = $true
      Stop-Job -Job $m.Job | Out-Null
      Remove-Job -Job $m.Job | Out-Null
    }
    else {
      $rawText = (Receive-Job -Job $m.Job | Out-String).Trim()
      Remove-Job -Job $m.Job | Out-Null
    }

    $end = Get-Date
    $result = Convert-RawToResult -AgentId $m.AgentId -StepName $m.StepName -Start $m.Start -End $end -RawText $rawText -TimedOut $timedOut -StepDir $m.StepDir
    $results[$m.StepName] = $result
  }

  Write-ProgressLog -Message ("parallel done: {0}" -f $names)
  return $results
}

function Test-UsableDebateText {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  $t = $Text.Trim().ToLowerInvariant()
  if ($t -like "(timeout*") { return $false }
  if ($t -eq "(empty response)") { return $false }
  if ($t -eq "(no text payload)") { return $false }
  if ($t.Contains("미완료")) { return $false }
  if ($t.Contains("판정 불가")) { return $false }
  if ($t.Contains("현재 검증 런")) { return $false }
  return ($Text.Trim().Length -ge 20)
}

function Test-UsableSynthesisText {
  param(
    [string]$Text,
    [string]$ProText,
    [string]$ConText
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  $t = $Text.Trim()
  $tl = $t.ToLowerInvariant()
  if ($tl -like "(timeout*") { return $false }
  if ($tl -eq "(empty response)") { return $false }
  if ($tl -eq "(no text payload)") { return $false }
  if ($tl.Contains("두 입장 원문이 현재 메시지에 없습니다")) { return $false }
  if ($tl.Contains("보내주시면")) { return $false }
  if ($tl.Contains("붙여주시면")) { return $false }
  if ($tl.Contains("정리하겠습니다")) { return $false }
  if ($tl.Contains("원문 없음")) { return $false }
  if ($tl.Contains("입장 a") -and $tl.Contains("입장 b")) { return $false }
  if ($t.Length -lt 60) { return $false }
  if ($t -notmatch "pro\s*의견|찬성\s*의견") { return $false }
  if ($t -notmatch "con\s*의견|반대\s*의견|리뷰\s*의견") { return $false }
  if ($t -notmatch "최종\s*결론|결론") { return $false }
  if ($t -notmatch "결론\s*이유") { return $false }
  if ($t -notmatch "즉시\s*액션|권장\s*액션") { return $false }
  if ([string]::IsNullOrWhiteSpace($ProText) -or [string]::IsNullOrWhiteSpace($ConText)) { return $false }
  return $true
}

function Build-FallbackSynthesis {
  param(
    [string]$TopicText,
    [string]$ProText,
    [string]$ConText
  )
  $proFirst = (($ProText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 2) -join " / ").Trim()
  $conFirst = (($ConText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 2) -join " / ").Trim()
  if ([string]::IsNullOrWhiteSpace($proFirst)) { $proFirst = "찬성 측은 속도 최적화와 실행 효율을 강조함." }
  if ([string]::IsNullOrWhiteSpace($conFirst)) { $conFirst = "반대 측은 안정성 리스크와 실패율 관리 필요성을 강조함." }
  return @"
Pro 의견
- $proFirst

Con 의견
- $conFirst

최종 결론
- 주제 '$TopicText'는 성능 품질을 유지하면서 지연을 낮추기 위해, 검증형 오케스트레이션(역할 분리 + 실패 제어 + 품질 게이트)을 적용하는 것이 타당하다.

결론 이유
- Pro는 실행성과 속도 개선 포인트를 제시했고, Con은 실패/리스크 제어 조건을 제시했다.
- 두 의견이 충돌하기보다 상호보완적이므로, 검증 기준을 포함한 실행안이 최적이다.

즉시 액션(3개)
- 1) pro->con->judge 순차 토론으로 바꾸고 con이 pro를 직접 검토하게 한다.
- 2) 합성 품질 게이트를 통과한 결과만 채택하고 실패 시 안전 폴백을 사용한다.
- 3) timeout_rate, retry_success_rate, fallback_rate를 매일 집계해 파라미터를 조정한다.
"@
}

$resolvedTopic = Resolve-Topic -TopicText $Topic -RequestText $Request
if ([string]::IsNullOrWhiteSpace($resolvedTopic)) {
  throw "Topic is empty. Use -Topic or -Request (e.g. 'OOO에 대해 토론해봐')."
}
Write-ProgressLog -Message ("run start: topic='{0}', runDir='{1}'" -f $resolvedTopic, $runDir)

$proPrompt = @"
주제: $resolvedTopic
역할: Pro(추진/실행 관점).
요구사항:
1) 핵심 주장 3개
2) 예상 반박 2개 + 재반박
3) 실행안 2개
형식: 불릿 위주, 14줄 이내.
중요: 현재 런 상태/파일 경로/로그 언급 금지.
"@

# Step 1) Pro first
$pro = Invoke-AgentTurn -AgentId "janggi" -Prompt $proPrompt -StepName "01-pro" -TimeoutSec $StepTimeoutSec
$proOk = Test-UsableDebateText -Text $pro.text

if (-not $proOk) {
  $proRetryPrompt = @"
주제: $resolvedTopic
역할: Pro(추진/실행).
형식 엄수:
- 주장 3개
- 반박 대응 2개
- 실행안 2개
12줄 이내, 평문으로만 작성.
현재 실행 상태/로그/파일 경로 언급 금지.
"@
  $proRetry = Invoke-AgentTurn -AgentId "janggi" -Prompt $proRetryPrompt -StepName "01b-pro-retry" -TimeoutSec $StepTimeoutSec
  if (Test-UsableDebateText -Text $proRetry.text) {
    $pro = $proRetry
    $proOk = $true
  }
}

# Step 2) Con reviews Pro
$proForCon = if ($proOk) { $pro.text } else { "(pro 응답 불충분: 일반 리스크 리뷰를 수행하라)" }
$conPrompt = @"
주제: $resolvedTopic
역할: Con(비판/리뷰 관점).
아래 Pro 의견을 검토해서 답하라.
[Pro 의견]
$proForCon

요구사항:
- 반론 또는 보완점 3개
- Pro 주장의 취약점 2개
- 안전 대안 2개
- 만약 Pro가 전반적으로 타당하면 '주요 반대 없음'을 명시하고 보완점 중심으로 작성
형식: 불릿 위주, 14줄 이내.
현재 실행 상태/로그/파일 경로 언급 금지.
"@

$con = Invoke-AgentTurn -AgentId "debate" -Prompt $conPrompt -StepName "02-con" -TimeoutSec $StepTimeoutSec
$conOk = Test-UsableDebateText -Text $con.text
if (-not $conOk) {
  $conRetryPrompt = @"
주제: $resolvedTopic
역할: Con(비판/리스크 리뷰).
아래 Pro 의견을 검토하라.
[Pro 의견]
$proForCon

형식 엄수:
- 반론/보완 3개
- 취약점 2개
- 안전대안 2개
12줄 이내, 평문으로만 작성.
현재 실행 상태/로그/파일 경로 언급 금지.
"@
  $conRetry = Invoke-AgentTurn -AgentId "debate" -Prompt $conRetryPrompt -StepName "02b-con-retry" -TimeoutSec $StepTimeoutSec
  if (Test-UsableDebateText -Text $conRetry.text) {
    $con = $conRetry
    $conOk = $true
  }
}

if ($proOk -and $conOk) {
  if ($SynthesisMode -eq "local-first") {
    Write-ProgressLog -Message "synthesis start (local-first deterministic)"
    $localStepDir = Join-Path $runDir "03-synthesis-local"
    New-Item -ItemType Directory -Path $localStepDir -Force | Out-Null
    $localText = Build-FallbackSynthesis -TopicText $resolvedTopic -ProText $pro.text -ConText $con.text
    Save-Text -Path (Join-Path $localStepDir "prompt.txt") -Text "(local deterministic synthesis)"
    Save-Text -Path (Join-Path $localStepDir "answer.txt") -Text $localText
    $synth = [pscustomobject]@{
      agent = "main"
      step = "03-synthesis-local"
      elapsedSec = 0
      text = $localText
      usage = $null
      parse = "local_primary"
    }
    Save-Json -Path (Join-Path $localStepDir "result.json") -Obj $synth
  }
  else {
    Write-ProgressLog -Message "synthesis start (model-first)"
    $proForJudge = Normalize-ForSynthesis -Text $pro.text -MaxChars $SynthesisMaxChars
    $conForJudge = Normalize-ForSynthesis -Text $con.text -MaxChars $SynthesisMaxChars
    $synthPrompt = @"
아래 Pro/Con 의견을 심사해서 최종 결론을 작성해라.
단순 요약 금지. 충돌 지점과 채택/기각 이유를 판단하라.
출력 형식(반드시 준수):
- Pro 의견 요약
- Con 의견 요약
- 최종 결론
- 결론 이유
- 즉시 액션(3개)

[Pro]
$proForJudge

[Con]
$conForJudge
"@
    $synth = Invoke-AgentTurn -AgentId "main" -Prompt $synthPrompt -StepName "03-synthesis" -TimeoutSec $SynthesisTimeoutSec

    if (-not (Test-UsableSynthesisText -Text $synth.text -ProText $pro.text -ConText $con.text)) {
      Write-ProgressLog -Level "WARN" -Message "synthesis quality check failed, retrying with strict prompt"
      $strictSynthPrompt = @"
다음은 이미 확보된 Pro/Con 원문이다.
원문 없음 같은 표현을 쓰지 말고 반드시 최종 판정 결론을 작성해라.
출력 형식(반드시 준수):
- Pro 의견 요약
- Con 의견 요약
- 최종 결론
- 결론 이유
- 즉시 액션 3개

[Pro 원문]
$proForJudge

[Con 원문]
$conForJudge
"@
      $synthRetry = Invoke-AgentTurn -AgentId "main" -Prompt $strictSynthPrompt -StepName "03b-synthesis-retry" -TimeoutSec $SynthesisTimeoutSec
      if (Test-UsableSynthesisText -Text $synthRetry.text -ProText $pro.text -ConText $con.text) {
        $synth = $synthRetry
      }
      else {
        Write-ProgressLog -Level "WARN" -Message "synthesis retry failed, using local fallback synthesis"
        $fallbackStepDir = Join-Path $runDir "03c-synthesis-fallback"
        New-Item -ItemType Directory -Path $fallbackStepDir -Force | Out-Null
        $fallbackText = Build-FallbackSynthesis -TopicText $resolvedTopic -ProText $pro.text -ConText $con.text
        Save-Text -Path (Join-Path $fallbackStepDir "prompt.txt") -Text "(local fallback synthesis)"
        Save-Text -Path (Join-Path $fallbackStepDir "answer.txt") -Text $fallbackText
        $synth = [pscustomobject]@{
          agent = "main"
          step = "03c-synthesis-fallback"
          elapsedSec = 0
          text = $fallbackText
          usage = $null
          parse = "local_fallback"
        }
        Save-Json -Path (Join-Path $fallbackStepDir "result.json") -Obj $synth
      }
    }
  }
}
else {
  Write-ProgressLog -Level "WARN" -Message ("partial debate detected: proOk={0}, conOk={1}; using fallback synthesis" -f $proOk, $conOk)
  $fallbackStepDir = Join-Path $runDir "03c-synthesis-fallback"
  New-Item -ItemType Directory -Path $fallbackStepDir -Force | Out-Null
  $fallbackText = Build-FallbackSynthesis -TopicText $resolvedTopic -ProText $pro.text -ConText $con.text
  Save-Text -Path (Join-Path $fallbackStepDir "prompt.txt") -Text "(local fallback synthesis due to missing side)"
  Save-Text -Path (Join-Path $fallbackStepDir "answer.txt") -Text $fallbackText
  $synth = [pscustomobject]@{
    agent = "main"
    step = "03c-synthesis-fallback"
    elapsedSec = 0
    text = $fallbackText
    usage = $null
    parse = "local_fallback_partial"
  }
  Save-Json -Path (Join-Path $fallbackStepDir "result.json") -Obj $synth
}

$summary = [pscustomobject]@{
  topic = $resolvedTopic
  request = $Request
  runDir = $runDir
  pro = $pro
  con = $con
  synthesis = $synth
}

Save-Json -Path (Join-Path $runDir "summary.json") -Obj $summary
Write-ProgressLog -Message ("run end: pro={0}, con={1}, synth={2}" -f $pro.parse, $con.parse, $synth.parse)
$summary | ConvertTo-Json -Depth 20


