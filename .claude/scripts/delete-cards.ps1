[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "ByPath")]
    [string]$CardPath,
    [Parameter(Mandatory = $true, ParameterSetName = "ById")]
    [string]$Id,
    [Parameter(Mandatory = $true, ParameterSetName = "ByAnkiNoteId")]
    [string]$AnkiNoteId
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$TargetArg = switch ($PSCmdlet.ParameterSetName) {
    "ByPath"       { "path=`"$CardPath`"" }
    "ById"         { "id=`"$Id`"" }
    "ByAnkiNoteId" { "anki_note_id=`"$AnkiNoteId`"" }
}

$Prompt = "/delete-cards $TargetArg"
$SystemPrompt = @"
この実行では、本プロジェクトの問題削除タスクのみを実行する。
プロジェクトのCLAUDE.md、および明示的に呼び出された /delete-cards Skillに従う。
削除対象は、実行時に指定された1種類の識別子だけで特定する。使用できる識別子は、問題カードのファイルパス、ローカルID、Anki Note IDのいずれか1種類とし、同一実行内で複数種類を混在させない。
ディレクトリ指定、ワイルドカード指定、問題文やタグからの推測によって削除対象を決定してはならない。カンマ区切りで複数値が指定された場合は、同一種類の識別子による複数の独立した削除対象として扱う。
各削除対象について、`cards/` 配下から対応する単一の問題カードを特定し、`anki_note_id`, `note_type`, `status` を確認する。
`anki_note_id` が設定されている場合は、ローカルファイルを削除する前に、AnkiMCPの `notes_info` で対象ノートを確認し、`delete_notes` でAnki側のノートを削除する。
Anki側の対象ノートが既に存在しない場合は、Anki側の削除は完了済みとして扱い、ローカル問題カードの削除を続行してよい。
AnkiMCPによる削除処理そのものが失敗した場合は、ローカル問題カードを削除せず、失敗内容を報告する。
Anki未登録の問題カード、またはAnki側の削除が完了したことを確認できた問題カードだけ、対応するローカル問題カードを削除する。
Ankiノートの追加・更新を行わない。`note_type` を変更しない。指定された削除対象以外の問題カードやAnkiノートを変更または削除しない。
処理完了後は、各削除対象についてAnkiノートとローカル問題カードの削除結果を簡潔に返す。
"@

& claude -p $Prompt `
    --output-format json `
    --system-prompt $SystemPrompt `
    --permission-mode dontAsk `
    --effort high `
    --tools "Read,Glob,Grep,Bash,Skill,ToolSearch" `
    --allowedTools "Read" "Glob" "Grep" "Bash" "ToolSearch" "Skill(delete-cards *)" `
        "mcp__anki__notes_info" "mcp__anki__delete_notes" `
    --disallowedTools "Write" "Edit" "mcp__anki__add_note" "mcp__anki__add_notes" "mcp__anki__update_note_fields" `
        "mcp__anki__update_notes" "mcp__anki__tag_management" "mcp__anki__create_deck" "mcp__anki__change_note_type" `
        "mcp__anki__model_fields" "mcp__anki__create_model" "mcp__anki__update_model_templates" "mcp__anki__update_model_styling"

exit $LASTEXITCODE
