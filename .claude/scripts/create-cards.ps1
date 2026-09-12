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
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

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

& claude -p $Prompt `
    --output-format json `
    --system-prompt $SystemPrompt `
    --permission-mode dontAsk `
    --effort high `
    --tools "Read,Write,Glob,Grep,Skill" `
    --allowedTools "Read" "Write" "Glob" "Grep" "Skill(create-cards *)" `
    --disallowedTools "Edit" "Bash" "mcp__*"

exit $LASTEXITCODE
