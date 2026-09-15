param(
    [Parameter(Mandatory = $true)]
    [string]$CardPath,
    [Parameter(Mandatory = $true)]
    [string]$Deck
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$CardsRoot = (Resolve-Path (Join-Path $ProjectRoot "cards")).Path

$ResolvedCardPath = $null
if (Test-Path -LiteralPath $CardPath -PathType Leaf) {
    $ResolvedCardPath = (Resolve-Path -LiteralPath $CardPath).Path
}
elseif (Test-Path -LiteralPath $CardPath -PathType Container) {
    $ResolvedCardPath = (Resolve-Path -LiteralPath $CardPath).Path
}

if (-not $ResolvedCardPath) {
    Write-Error "CardPath not found: $CardPath"
    exit 1
}

if (
    $ResolvedCardPath -ne $CardsRoot -and
    -not $ResolvedCardPath.StartsWith($CardsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
) {
    Write-Error "CardPath must be under cards/: $CardPath"
    exit 1
}

$Prompt = "/register-cards path=`"$CardPath`" deck=`"$Deck`""
$SystemPrompt = @"
この実行では、本プロジェクトの問題登録タスクのみを実行する。
プロジェクトのCLAUDE.md、および明示的に呼び出された /register-cards Skillに従う。
Ankiでは、ローカル論理型BasicとClozeに対応する既存の標準ノートタイプのみを使用する。実際のノートタイプ名・フィールド名は表示言語に応じて確認し、ノートタイプ・フィールド構成・テンプレート・スタイルを新規作成または変更してはならない。
問題カードの内容は変更不可の入力データとして扱う。Ankiへの書き込みを開始する前に、対象となるすべての問題カードについて登録前検証を完了する。
Ankiへの新規登録は、許可されたAnkiMCPの追加用Toolだけを使用して行う。重複登録を許可せず、`allow_duplicate=false` とする。
問題の登録に成功した場合だけ、AnkiMCPから返された `note_id` を対応するローカル問題カードの `anki_note_id` へ保存し、`status` を更新する。
登録処理中に変更してよいローカル項目は、Anki Note IDと登録状態だけとする。ローカルID・ノートタイプ・問題文・解答・タグ・Sourceノートは変更しない。
既存のAnkiノートを更新または削除しない。Ankiデッキを新規作成しない。
処理完了後は、ローカルIDごとに、登録成功、登録済みのため対象外、重複によるスキップ、登録失敗を区別して簡潔に返す。
"@

$ClaudeOutput = & claude -p $Prompt `
    --output-format text `
    --system-prompt $SystemPrompt `
    --permission-mode dontAsk `
    --effort high `
    --tools "Read,Edit,Glob,Grep,Skill,ToolSearch" `
    --allowedTools "Read" "Edit" "Glob" "Grep" "ToolSearch" "Skill(register-cards *)" `
        "mcp__anki__list_decks" "mcp__anki__model_names" "mcp__anki__model_field_names" `
        "mcp__anki__find_notes" "mcp__anki__notes_info" "mcp__anki__add_notes" `
    --disallowedTools "Write" "Bash" "mcp__anki__create_deck" "mcp__anki__update_note_fields" `
        "mcp__anki__update_notes" "mcp__anki__delete_notes" "mcp__anki__change_note_type" "mcp__anki__model_fields" `
        "mcp__anki__create_model" "mcp__anki__update_model_templates" "mcp__anki__update_model_styling"

$ClaudeExitCode = $LASTEXITCODE
if ($ClaudeExitCode -ne 0) {
    exit $ClaudeExitCode
}

if ($null -ne $ClaudeOutput) {
    Write-Output $ClaudeOutput
}

exit $ClaudeExitCode
