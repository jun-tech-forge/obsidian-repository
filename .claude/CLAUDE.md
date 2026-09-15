# 暗記カード作成プロジェクト

## Project Overview

本プロジェクトは、Obsidian Vaultに蓄積した学習ノートからClaude Codeで暗記カード原本を作成し、AnkiMCPを介してAnkiで学習できる状態へ登録・管理するためのシステムである。

VaultルートをClaude Codeのプロジェクトルートとして扱う。

主要なデータは次の場所で管理する。

- `notes/`: 問題作成の情報源となる学習ノート
- `cards/`: 生成した問題カードのローカル原本
- `.claude/skills/`: 問題作成・登録・更新・削除の各タスク
- `.claude/rules/`: Sourceノートの種類に応じて適用するPath-specific rules
- `.claude/doc/`: 詳細仕様および参考情報

## Core Principles

- 問題作成・問題登録・問題更新・問題削除は独立したタスクとして扱い、1回の実行では1種類のタスクだけを実行する
- `cards/` 配下の問題カードを問題データのローカル原本とし、Ankiをローカル原本の管理基準にしない
- ローカルの `note_type` には論理名 `Basic` と `Cloze` だけを使用し、Ankiでは表示言語に応じた対応する標準ノートタイプだけを使用する
- 独自ノートタイプの作成、標準ノートタイプへの独自フィールド追加、ノートタイプ構成の自動変更を行わない
- ローカル管理情報の `id`, `anki_note_id`, `status`, `note_type`, `source` をAnkiのフィールドとして登録しない
- 利用者が明示したタスクおよび対象を越えて、既存の問題カードやAnkiノートを変更しない
- 対象や識別子が一意に確認できない場合は推測して処理しない

## Task Boundaries

### Problem Creation

- 新しい問題カードだけを作成する
- 既存の問題カードを変更または上書きしない
- Ankiを操作しない

### Problem Registration

- 未登録の問題カードをAnkiへ新規登録する
- 問題カードの内容を変更しない
- 登録成功後に変更できるローカル項目は `anki_note_id` と `status` だけとする
- 既存のAnkiノートを更新または削除しない

### Problem Update

- 利用者が明示した既存問題カードだけを変更する
- 指示されていない内容へ変更を広げない
- Ankiへ同期する場合は、保存済みの `anki_note_id` で対象ノートを特定する
- Ankiへの新規登録または削除を行わない

### Problem Deletion

- 利用者が明示した問題カードだけを削除する
- Anki登録済みの場合は、Anki側の削除結果を確認してからローカル原本を削除する
- 問題内容やタグから削除対象を推測しない

## Reference Documents

タスク固有の詳細はCLAUDE.mdへ重複して記載せず、必要なタスクのSkillから次の正本を参照する。

- `.claude/doc/flashcard_workflow_spec.md`: システム全体・タスク境界・処理仕様・実行条件・エラー処理
- `.claude/doc/card_format_reference.md`: 問題カードのデータ形式・各項目・タグ・品質条件
- `.claude/doc/ankimcp_reference.md`: AnkiMCPのTool、入出力、Anki標準ノートタイプとの対応
- `.claude/doc/headless_command_reference.md`: ヘッドレス実行・CLIフラグ・実行スクリプト

仕様間で矛盾を検出した場合は推測で解消せず、処理を停止して矛盾箇所を報告する。

## Rules and Skills

- タスク固有の処理手順と制約は `.claude/skills/` 配下の対応するSkillに従う
- `notes/` 配下のSourceノートを扱う場合は、対象パスに一致する `.claude/rules/` 配下のPath-specific rulesに従う
- SourceノートはClaude CodeのRead Toolで読み込み、対象パスに対応するPath-specific rulesを適用する
- `notes/` 配下の分類は追加される可能性があるため、特定の分類フォルダだけが存在することを前提にしない
