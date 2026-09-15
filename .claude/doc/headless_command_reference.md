# ヘッドレス実行コマンド仕様

## 1. 基本方針

Claude Codeの非対話実行には `claude -p` を使用する。本プロジェクトでは各タスクで `--output-format` と `--system-prompt` を明示する。

`--output-format` はカードファイルの形式を指定するものではなく、Claude Codeが標準出力へ返す応答形式を指定する。本処理では利用者向けの最終結果だけを簡潔に表示するため `text` を使用する。

`--system-prompt` はClaude Codeの既定system prompt全体を置換する。本要件ではこのフラグを必須とするため、各スクリプト内のsystem promptにタスク境界、安全条件、プロジェクト指示参照を明示する。

---

## 2. 共通フラグ

- `-p`: 非対話で1タスクを実行し、終了する。
- `--output-format text`: 実行結果をテキストで返す。
- `--system-prompt`: タスク固有の実行責務と禁止事項を指定する。
- `--permission-mode dontAsk`: 許可されていないToolを対話確認せず拒否する。
- `--tools`: 利用可能な組み込みToolをタスクごとに絞る。
- `--allowedTools`: ヘッドレスで自動承認するToolを限定する。
- `--disallowedTools`: 更新・削除などタスク境界外のToolを明示拒否する。
- `--effort high`: settings.jsonと同じく、カード品質とコストの均衡を取る。

---

## 3. 問題作成タスク

```powershell
.\.claude\scripts\create-cards.ps1 `
  -Source "notes\books\example.md" `
  -Deck "it" `
  -TagPath "cards\it\web_application\frontend" `
  -Count 12
```

- `Source`: 元ノートのVault相対パス。
- `Deck`: 登録予定のAnkiデッキ名。
- `TagPath`: `cards/` 配下の既存保存先ディレクトリ。
- `Count`: 作成件数の上限目安。十分な知識がなければ少なくてよい。

`create-cards.ps1` はClaude Code起動前に、PowerShellの `Test-Path` で次を検証する。

- `Source` が `notes/` 配下の実在するMarkdownファイルであること
- `TagPath` が `cards/` 配下の実在するディレクトリであること

`TagPath` は `Test-Path -PathType Container` で確認するため、空ディレクトリでも存在していれば正常と判定する。条件を満たさない場合はClaude Codeを起動せず終了する。

1つのMarkdown学習メモから複数問を作る場合も、`--output-format` を変更する必要はない。Claudeは複数のカードMarkdownファイルを作成し、標準出力には利用者向けの実行結果テキストを返す。

新規カードは `anki_note_id: null`、`status: draft` とする。

---

## 4. 問題登録タスク

```powershell
.\.claude\scripts\register-cards.ps1 `
  -CardPath "cards\it\web_application\frontend" `
  -Deck "it"
```

登録タスクはカード本文を変更しない。ローカル論理型 `Basic` / `Cloze` に対応するAnki標準ノートタイプへ新規登録し、成功したカードについてのみローカルfrontmatterの `anki_note_id` と `status` を更新する。

`register-cards.ps1` はClaude Code起動前に、PowerShellの `Test-Path` で `CardPath` が `cards/` 配下の実在するファイルまたはディレクトリであることを検証する。ディレクトリは空でも、存在していれば有効な入力として扱う。条件を満たさない場合はClaude Codeを起動せず終了する。

変換規則は次のとおりである。

```text
Basic:
  note_type=Basic
  model_name → Anki Basic または 基本
  front      → Anki Front または 表面
  back       → Anki Back または 裏面
  tags       → Anki native tags

Cloze:
  note_type=Cloze
  model_name → Anki Cloze または 穴埋め問題
  text       → Anki Text または テキスト
  back_extra → Anki Back Extra または 裏面追記
  tags       → Anki native tags

ローカルのみ:
  id
  anki_note_id
  status
  source
```

実際に使用するノートタイプ名とフィールド名は、`model_names` と `model_field_names` で確認した値に限る。`基本 コピー` や `基本 (裏表反転カード付き)` のような類似名は推測で使用しない。

---

## 5. 更新タスク

更新対象は `-CardPath`（ファイルパス）・`-Id`（ローカルID）・`-AnkiNoteId`（Anki Note ID）のいずれか1つで指定する。1回の実行で2つ以上を同時に指定してはならない。

ローカル原本だけを変更する場合:

```powershell
.\.claude\scripts\update-cards.ps1 `
  -CardPath "cards\it\web_application\frontend\it-20260901T044300-001.md" `
  -Instruction "backの補足をより簡潔にする"
```

```powershell
.\.claude\scripts\update-cards.ps1 `
  -Id "it-20260901T044300-001" `
  -Instruction "backの補足をより簡潔にする"
```

```powershell
.\.claude\scripts\update-cards.ps1 `
  -AnkiNoteId 1757081234567 `
  -Instruction "backの補足をより簡潔にする"
```

登録済みカードをローカルだけ変更した場合は `status: needs_sync` とする。

Ankiにも明示同期する場合は、識別子の種類によらず `-SyncAnki` を付与する:

```powershell
.\.claude\scripts\update-cards.ps1 `
  -CardPath "cards\it\web_application\frontend\it-20260901T044300-001.md" `
  -Instruction "backの補足をより簡潔にする" `
  -SyncAnki
```

`-SyncAnki` を使用する場合、対象カードに `anki_note_id` が保存されていることが必須である。Note IDを `notes_info` で確認し、ローカル論理型に対応する実ノートタイプ名と実フィールド名を特定してから標準フィールドを更新し、同期成功後に `status: registered` とする。

`id`、`anki_note_id`、`note_type` の変更、およびノート削除は更新タスクでは行わない。

---

## 6. 削除タスク

削除対象は `-CardPath`・`-Id`・`-AnkiNoteId` のいずれか1つで指定する。1回の実行で2つ以上を同時に指定してはならない。

```powershell
.\.claude\scripts\delete-cards.ps1 `
  -Id "it-20260901T044300-001"
```

```powershell
.\.claude\scripts\delete-cards.ps1 `
  -CardPath "cards\it\web_application\frontend\it-20260901T044300-001.md"
```

```powershell
.\.claude\scripts\delete-cards.ps1 `
  -AnkiNoteId 1757081234567
```

`-Id` および `-CardPath` は、同じ種類の識別子であればカンマ区切りで複数指定できる（例: `-Id "id-1,id-2"`）。異なる種類の識別子を1回の実行で混在させてはならない。

削除タスクは、指定した識別子で特定したカードについて、Anki側のノートとVault側のカードファイルを両方削除する。ローカルだけを残す、またはAnki側だけを残すという選択肢はない。

`anki_note_id` が存在するカードは、`notes_info` で対象ノートを確認してから `delete_notes` で削除する。`anki_note_id` が `null`（未登録）のカードは、Anki側の削除を行わずローカルのカードファイルだけを削除する。

Anki側の削除に失敗した場合は、ローカルのカードファイルを削除せずタスクを中止する。

---

## 7. 実行前確認

```powershell
claude --version
claude mcp list
claude mcp get anki
```
