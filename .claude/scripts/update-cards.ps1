[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "ByPath")]
    [string]$CardPath,
    [Parameter(Mandatory = $true, ParameterSetName = "ById")]
    [string]$Id,
    [Parameter(Mandatory = $true, ParameterSetName = "ByAnkiNoteId")]
    [string]$AnkiNoteId,
    [Parameter(Mandatory = $true)]
    [string]$Instruction,
    [switch]$SyncAnki
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$TargetArg = switch ($PSCmdlet.ParameterSetName) {
    "ByPath"       { "path=`"$CardPath`"" }
    "ById"         { "id=`"$Id`"" }
    "ByAnkiNoteId" { "anki_note_id=`"$AnkiNoteId`"" }
}

$SyncValue = if ($SyncAnki) { "true" } else { "false" }
$Prompt = "/update-cards $TargetArg instruction=`"$Instruction`" sync_anki=$SyncValue"
$SystemPrompt = @"
この実行では、本プロジェクトの既存問題更新タスクのみを実行する。
プロジェクトのCLAUDE.md、および明示的に呼び出された /update-cards Skillに従う。
更新対象は、実行時に指定された1種類の識別子だけで特定する。使用できる識別子は、問題カードのファイルパス、ローカルID、Anki Note IDのいずれか1種類とし、処理を開始する前に `cards/` 配下の単一の問題カードへ一意に対応付ける。
問題文やタグ等から更新対象を推測してはならない。
利用者が `instruction` で明示した内容だけを変更する。指定されていない項目を追加・改善・修正してはならない。
`id` および `anki_note_id` は変更しない。Anki登録済みの問題カードでは `note_type` を変更しない。
Ankiノートの新規追加または削除を行わない。
`sync_anki=false` の場合は、ローカル問題カードだけを更新し、AnkiMCPを使用しない。対象が `status: registered` の場合は、ローカル原本とAnkiの内容に差分が生じるため、更新後の `status` を `needs_sync` とする。対象が `status: draft` の場合は、`status: draft` を維持する。
`sync_anki=true` の場合は、ローカル問題カードに保存された `anki_note_id` だけを使用してAnki側の対象ノートを特定する。AnkiMCPの `notes_info` で対象ノートを確認した後、利用者が明示的に変更した内容に対応するBasicまたはClozeの標準フィールドだけを更新する。タグが明示的に変更された場合だけ、Anki側のタグにも変更内容を反映する。
Ankiへの同期が成功した場合は `status` を `registered` とする。同期に失敗した場合は、ローカルで行った変更を元に戻さず、`status` を `needs_sync` とする。
指定された対象以外の問題カードやAnkiノートを変更してはならない。
処理完了後は、更新対象、ローカルで変更した項目、Anki同期の実施有無、同期結果、更新後の `status` を簡潔に返す。
"@

if ($SyncAnki) {
    $ClaudeOutput = & claude -p $Prompt `
        --output-format text `
        --system-prompt $SystemPrompt `
        --permission-mode dontAsk `
        --effort high `
        --tools "Read,Edit,Glob,Grep,Skill,ToolSearch" `
        --allowedTools "Read" "Edit" "Glob" "Grep" "ToolSearch" "Skill(update-cards *)" `
            "mcp__anki__notes_info" "mcp__anki__update_note_fields" "mcp__anki__update_notes" "mcp__anki__tag_management" `
        --disallowedTools "Write" "Bash" "mcp__anki__add_note" "mcp__anki__add_notes" "mcp__anki__delete_notes" `
            "mcp__anki__create_deck" "mcp__anki__change_note_type" "mcp__anki__model_fields" "mcp__anki__create_model" `
            "mcp__anki__update_model_templates" "mcp__anki__update_model_styling"
}
else {
    $ClaudeOutput = & claude -p $Prompt `
        --output-format text `
        --system-prompt $SystemPrompt `
        --permission-mode dontAsk `
        --effort high `
        --tools "Read,Edit,Glob,Grep,Skill" `
        --allowedTools "Read" "Edit" "Glob" "Grep" "Skill(update-cards *)" `
        --disallowedTools "Write" "Bash" "mcp__*"
}

$ClaudeExitCode = $LASTEXITCODE
if ($ClaudeExitCode -ne 0) {
    exit $ClaudeExitCode
}

if ($null -ne $ClaudeOutput) {
    Write-Output $ClaudeOutput
}

exit $ClaudeExitCode
