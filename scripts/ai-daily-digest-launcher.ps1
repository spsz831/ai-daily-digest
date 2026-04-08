param()

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$digestTs = Join-Path $projectDir 'scripts\digest.ts'
$outputDir = Join-Path $projectDir 'reports\output'
$healthDir = Join-Path $projectDir 'reports\health'

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Allowed,
        [string]$Default
    )

    while ($true) {
        $value = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }
        if ($Allowed -contains $value) {
            return $value
        }
        Write-Host "输入无效 / Invalid input. Allowed: $($Allowed -join ', ')"
    }
}

if (-not (Test-Path -LiteralPath $digestTs)) {
    throw "未找到项目脚本 / Project script not found: $digestTs"
}

New-Item -ItemType Directory -Force -Path $outputDir, $healthDir | Out-Null

Write-Host ""
Write-Host "=========================================="
Write-Host "  AI Daily Digest Launcher / AI 日报启动器"
Write-Host "=========================================="
Write-Host ""

Write-Host "[1/7] 选择时间范围 / Select time range:"
Write-Host "  1) 24 小时 / 24 hours"
Write-Host "  2) 48 小时（推荐） / 48 hours (recommended)"
Write-Host "  3) 72 小时 / 72 hours"
Write-Host "  4) 7 天（168 小时） / 7 days (168 hours)"
$hoursChoice = Read-Choice "请输入 1-4 / Choose 1-4" @('1','2','3','4') '2'
$hours = @{ '1' = 24; '2' = 48; '3' = 72; '4' = 168 }[$hoursChoice]
Write-Host "已选择 / Selected: $hours hours"
Write-Host ""

Write-Host "[2/7] 选择文章数量 / Select article count:"
Write-Host "  1) 10 篇 / 10"
Write-Host "  2) 15 篇（推荐） / 15 (recommended)"
Write-Host "  3) 20 篇 / 20"
$topChoice = Read-Choice "请输入 1-3 / Choose 1-3" @('1','2','3') '2'
$topN = @{ '1' = 10; '2' = 15; '3' = 20 }[$topChoice]
Write-Host "已选择 / Selected: $topN"
Write-Host ""

Write-Host "[3/7] 选择语言 / Select language:"
Write-Host "  1) 中文 / Chinese (zh)"
Write-Host "  2) 英文 / English (en)"
$langChoice = Read-Choice "请输入 1-2 / Choose 1-2" @('1','2') '1'
$lang = if ($langChoice -eq '2') { 'en' } else { 'zh' }
Write-Host "已选择 / Selected: $lang"
Write-Host ""

Write-Host "[4/7] 是否包含 WaytoAGI 最新文章 / Include WaytoAGI latest posts:"
Write-Host "  1) 不包含（默认） / Disable (0, default)"
Write-Host "  2) 5 篇 / 5 posts"
Write-Host "  3) 10 篇 / 10 posts"
$wayChoice = Read-Choice "请输入 1-3 / Choose 1-3" @('1','2','3') '1'
$waytoagiLimit = @{ '1' = 0; '2' = 5; '3' = 10 }[$wayChoice]
Write-Host "已选择 WaytoAGI 数量 / Selected WaytoAGI limit: $waytoagiLimit"
Write-Host ""

Write-Host "[5/7] 选择 Gemini 模型 / Select Gemini model:"
Write-Host "  1) gemini-flash-latest (默认 / 推荐 | default / recommended)"
Write-Host "  2) gemini-3-flash-preview"
Write-Host "  3) gemini-3-pro-preview"
Write-Host "  4) gemini-3.1-pro-preview"
Write-Host "  5) 自定义模型名 / Custom model name"
$geminiChoice = Read-Choice "请输入 1-5 / Choose 1-5" @('1','2','3','4','5') '1'
$geminiModel = switch ($geminiChoice) {
    '2' { 'gemini-3-flash-preview' }
    '3' { 'gemini-3-pro-preview' }
    '4' { 'gemini-3.1-pro-preview' }
    '5' { Read-Host "请输入自定义 Gemini 模型名 / Enter custom Gemini model name" }
    default { 'gemini-flash-latest' }
}
if ([string]::IsNullOrWhiteSpace($geminiModel)) { $geminiModel = 'gemini-flash-latest' }
Write-Host "已选择 Gemini 模型 / Selected Gemini model: $geminiModel"
Write-Host ""

Write-Host "[6/7] 选择 OpenAI 兜底模型 / Select OpenAI fallback model:"
Write-Host "  1) gpt-5.4 (默认 / default)"
Write-Host "  2) 使用环境变量中的 OPENAI_MODEL / Use current OPENAI_MODEL from environment"
Write-Host "  3) gpt-5.3-codex"
Write-Host "  4) 自定义模型名 / Custom model name"
$openaiChoice = Read-Choice "请输入 1-4 / Choose 1-4" @('1','2','3','4') '1'
$openaiModelOverride = switch ($openaiChoice) {
    '2' { '' }
    '3' { 'gpt-5.3-codex' }
    '4' { Read-Host "请输入自定义 OpenAI 模型名 / Enter custom OpenAI model name" }
    default { 'gpt-5.4' }
}
$openaiLabel = if ([string]::IsNullOrWhiteSpace($openaiModelOverride)) { '(env OPENAI_MODEL)' } else { $openaiModelOverride }
Write-Host "已选择 OpenAI 兜底模型 / Selected OpenAI fallback model: $openaiLabel"
Write-Host ""

Write-Host "[7/7] 确认配置 / Confirm:"
Write-Host "  时间范围 Hours         : $hours"
Write-Host "  文章数量 Top N         : $topN"
Write-Host "  语言 Language          : $lang"
Write-Host "  WaytoAGI 最新文章      : $waytoagiLimit"
Write-Host "  Gemini 模型            : $geminiModel"
Write-Host "  OpenAI 兜底模型        : $openaiLabel"
Write-Host "  项目目录 Project       : $projectDir"
Write-Host "  输出目录 Output        : $outputDir"
Write-Host ""
$confirm = Read-Choice "是否开始执行？ / Start now? (Y/N)" @('Y','y','N','n') 'Y'
if ($confirm -in @('N','n')) {
    Write-Host "已取消 / Cancelled."
    exit 0
}

if (-not $env:GEMINI_API_KEY -and -not $env:OPENAI_API_KEY) {
    throw "缺少 API Key，请先设置 GEMINI_API_KEY 和/或 OPENAI_API_KEY 到用户环境变量。"
}

$ts = Get-Date -Format 'yyyyMMdd-HHmm'
$outputFile = Join-Path $outputDir "ai-daily-digest-$ts.md"
$healthLogFile = Join-Path $healthDir "run-$ts.json"

Write-Host ""
Write-Host "正在生成日报，请稍候... / Generating digest, please wait..."

$env:GEMINI_MODEL = $geminiModel
if (-not [string]::IsNullOrWhiteSpace($openaiModelOverride)) {
    $env:OPENAI_MODEL = $openaiModelOverride
}

Push-Location $projectDir
try {
    $npxCmd = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
    if (-not $npxCmd) {
        $npxCmd = (Get-Command npx -ErrorAction Stop).Source
    }

    & $npxCmd -y bun scripts/digest.ts --hours $hours --top-n $topN --lang $lang --waytoagi-limit $waytoagiLimit --output $outputFile --health-log $healthLogFile
    if ($LASTEXITCODE -ne 0) {
        throw "生成失败 / Generation failed. Exit code: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "[OK] 已完成 / Done."
Write-Host "输出文件 Output file : $outputFile"
Write-Host "健康日志 Health log : $healthLogFile"
Write-Host "输出目录 Output dir : $outputDir"
Read-Host "按回车键关闭 / Press Enter to exit" | Out-Null
