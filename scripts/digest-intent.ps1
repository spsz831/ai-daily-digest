param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$IntentParts
)

$ErrorActionPreference = 'Stop'

function Test-ContainsAny {
  param(
    [string]$Text,
    [string[]]$Keywords
  )
  foreach ($k in $Keywords) {
    if ($Text -match [Regex]::Escape($k)) { return $true }
  }
  return $false
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$digestTs = Join-Path $projectDir 'scripts\digest.ts'
if (-not (Test-Path -LiteralPath $digestTs)) {
  throw "未找到脚本: $digestTs"
}

$defaultOutputDir = Join-Path $projectDir 'reports'
$outputDir = if ($env:DIGEST_OUTPUT_DIR) { $env:DIGEST_OUTPUT_DIR } else { $defaultOutputDir }
$healthDir = Join-Path $outputDir 'health'
New-Item -ItemType Directory -Force -Path $outputDir, $healthDir | Out-Null

$intent = ($IntentParts -join ' ').Trim()

if ($intent -match '(^|\s)(--help|help|/\?)(\s|$)' -or (Test-ContainsAny $intent @('帮助'))) {
  Write-Host "用法:"
  Write-Host "  scripts\digest-intent.cmd [自然语言意图]"
  Write-Host ""
  Write-Host "示例:"
  Write-Host "  scripts\digest-intent.cmd 来一份今日日报"
  Write-Host "  scripts\digest-intent.cmd AI快讯 英文"
  Write-Host "  scripts\digest-intent.cmd AI深度日报 waytoagi"
  Write-Host "  scripts\digest-intent.cmd AI日报 仅openai gpt-5.4"
  Write-Host ""
  Write-Host "说明:"
  Write-Host "  1) 不传参数时，默认 48h / 15 篇 / 中文。"
  Write-Host "  2) 你可以把多个短语写在一起，脚本会按关键词自动映射。"
  exit 0
}

# 默认参数
$hours = 48
$topN = 15
$lang = 'zh'
$waytoagiLimit = 0
$geminiModel = if ($env:GEMINI_MODEL) { $env:GEMINI_MODEL } else { 'gemini-flash-latest' }
$openaiModel = if ($env:OPENAI_MODEL) { $env:OPENAI_MODEL } else { 'gpt-5.4' }
$forceOpenAIOnly = $false

if ($intent) {
  if (Test-ContainsAny $intent @('晨报','午报','晚报','快讯','速览','brief','morning')) {
    $hours = 24; $topN = 10
  }
  if (Test-ContainsAny $intent @('深度','deep')) {
    $hours = 72; $topN = 20
  }
  if (Test-ContainsAny $intent @('周报','weekly','7天')) {
    $hours = 168; $topN = 20
  }
  if (Test-ContainsAny $intent @('今日','今天','今日日报','日报','daily digest')) {
    if ($hours -eq 48 -and $topN -eq 15) {
      $hours = 48; $topN = 15
    }
  }

  if (Test-ContainsAny $intent @('英文','english')) { $lang = 'en' }
  if (Test-ContainsAny $intent @('中文')) { $lang = 'zh' }

  if (Test-ContainsAny $intent @('waytoagi')) { $waytoagiLimit = 10 }
  if (Test-ContainsAny $intent @('不含waytoagi','no-waytoagi')) { $waytoagiLimit = 0 }

  if (Test-ContainsAny $intent @('flash-latest')) { $geminiModel = 'gemini-flash-latest' }
  if (Test-ContainsAny $intent @('flash-preview')) { $geminiModel = 'gemini-3-flash-preview' }
  if (Test-ContainsAny $intent @('3.1-pro-preview')) { $geminiModel = 'gemini-3.1-pro-preview' }
  elseif (Test-ContainsAny $intent @('pro-preview')) { $geminiModel = 'gemini-3-pro-preview' }

  if (Test-ContainsAny $intent @('gpt-5.4')) { $openaiModel = 'gpt-5.4' }
  if (Test-ContainsAny $intent @('gpt-5.3')) { $openaiModel = 'gpt-5.3-codex' }

  if (Test-ContainsAny $intent @('仅openai','只用openai','openai-only')) {
    $forceOpenAIOnly = $true
  }
}

if (-not $env:GEMINI_API_KEY -and -not $env:OPENAI_API_KEY) {
  throw '缺少 API Key：请至少设置 GEMINI_API_KEY 或 OPENAI_API_KEY。'
}

$ts = Get-Date -Format 'yyyyMMdd-HHmm'
$outputFile = Join-Path $outputDir ("digest-{0}.md" -f $ts)
$healthLog = Join-Path $healthDir ("run-{0}.json" -f $ts)

Write-Host ""
Write-Host "[digest-intent] Intent: $intent"
Write-Host "[digest-intent] Hours=$hours TopN=$topN Lang=$lang WaytoAGI=$waytoagiLimit"
Write-Host "[digest-intent] Gemini=$geminiModel OpenAI=$openaiModel"
if ($forceOpenAIOnly) { Write-Host "[digest-intent] openai-only: enabled" }
Write-Host ""

$env:GEMINI_MODEL = $geminiModel
$env:OPENAI_MODEL = $openaiModel
if ($forceOpenAIOnly) { $env:GEMINI_API_KEY = '' }

Push-Location $projectDir
try {
  $npxCmd = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
  if (-not $npxCmd) {
    $npxCmd = (Get-Command npx -ErrorAction Stop).Source
  }

  & $npxCmd -y bun scripts/digest.ts --hours $hours --top-n $topN --lang $lang --waytoagi-limit $waytoagiLimit --output $outputFile --health-log $healthLog
  if ($LASTEXITCODE -ne 0) {
    throw "digest 执行失败，退出码: $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "[OK] 日报已生成: $outputFile"
Write-Host "[OK] 健康日志: $healthLog"
