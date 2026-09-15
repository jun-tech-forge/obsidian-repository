param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Deck,
    [Parameter(Mandatory = $true)]
    [string]$TagPath,
    [int]$Count = 100
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$NotesRoot = (Resolve-Path (Join-Path $ProjectRoot "notes")).Path
$CardsRoot = (Resolve-Path (Join-Path $ProjectRoot "cards")).Path

$ResolvedSource = $null
if (Test-Path -LiteralPath $Source -PathType Leaf) {
    $ResolvedSource = (Resolve-Path -LiteralPath $Source).Path
}

if (-not $ResolvedSource) {
    Write-Error "Source file not found: $Source"
    exit 1
}

if ([System.IO.Path]::GetExtension($ResolvedSource) -ne ".md") {
    Write-Error "Source must be a Markdown file: $Source"
    exit 1
}

if (-not $ResolvedSource.StartsWith($NotesRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Source must be under notes/: $Source"
    exit 1
}

$ResolvedTagPath = $null
if (Test-Path -LiteralPath $TagPath -PathType Container) {
    $ResolvedTagPath = (Resolve-Path -LiteralPath $TagPath).Path
}

if (-not $ResolvedTagPath) {
    Write-Error "TagPath directory not found: $TagPath"
    exit 1
}

if (
    $ResolvedTagPath -ne $CardsRoot -and
    -not $ResolvedTagPath.StartsWith($CardsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
) {
    Write-Error "TagPath must be under cards/: $TagPath"
    exit 1
}

$Prompt = "/create-cards source=`"$Source`" deck=`"$Deck`" tag=`"$TagPath`" count=$Count"
$SystemPrompt = @"
この実行では、本プロジェクトの問題作成タスクのみを実行する。
プロジェクトのCLAUDE.md、明示的に呼び出された /create-cards Skill、およびSourceノートの読み込みによって適用されるPath-specific rulesに従う。
新しいローカル問題カードのみを作成する。ローカルの `note_type` にはAnki標準ノートタイプのBasicまたはClozeを使用するが、Ankiの操作やAnkiノートタイプの作成・変更は行わない。
新しく作成するすべての問題カードは、`anki_note_id` を `null`、`status` を `draft` とする。
既存の問題カードを更新または上書きしない。MCP Toolを使用しない。Ankiへの登録を行わない。
Path-specific rulesを適用するため、指定されたSourceノートはClaude Codeの Read Tool で読み込む。
ファイル操作完了後は、簡潔な実行結果のみを返す。
"@

$ClaudeOutput = & claude -p $Prompt `
    --output-format text `
    --system-prompt $SystemPrompt `
    --permission-mode dontAsk `
    --effort high `
    --tools "Read,Write,Glob,Grep,Skill" `
    --allowedTools "Read" "Write" "Glob" "Grep" "Skill(create-cards *)" `
    --disallowedTools "Edit" "Bash" "mcp__*"

$ClaudeExitCode = $LASTEXITCODE
if ($ClaudeExitCode -ne 0) {
    exit $ClaudeExitCode
}

if ($null -ne $ClaudeOutput) {
    Write-Output $ClaudeOutput
}

exit $ClaudeExitCode
