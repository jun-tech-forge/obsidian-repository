---
name: update-cards
description: 明示指定された既存問題カードだけを更新し、sync_anki=trueの場合に限り、保存済みのAnki Note IDで特定したAnkiノートへ変更内容を同期する。
disable-model-invocation: true
argument-hint: "(path=<cards/...md> | id=<local-id> | anki_note_id=<note-id>) instruction=<変更内容> sync_anki=<false|true>"
---

# Card Update

## Inputs

`$ARGUMENTS` から次の値を取得する。

- `path`: 更新対象の問題カードファイル
- `id`: 更新対象のローカルID
- `anki_note_id`: 更新対象のAnki Note ID
- `instruction`: 利用者が指定した変更内容
- `sync_anki`: 更新内容をAnkiへ同期するかを表す値

`path`, `id`, `anki_note_id` は、いずれか1つだけを指定する。

## References

処理を開始する前に、次の資料を読む。

- `.claude/doc/flashcard_workflow_spec.md` の問題更新タスクに関する章
- `.claude/doc/card_format_reference.md`
- `.claude/doc/ankimcp_reference.md`

## Preconditions

更新処理を開始する前に、次の条件を確認する。

### Target identification

- `path`, `id`, `anki_note_id` のうち指定されている識別子が1つだけである
- 指定された識別子から `cards/` 配下の単一の問題カードを特定できる
- 対象の問題カードをReadできる

対象が0件または複数件の場合は、更新せず終了する。

識別子ごとの対象特定方法は次のとおりとする。

- `path`: 指定された問題カードファイルを対象とする
- `id`: `cards/` 配下から `<id>.md` をGlobで検索する
- `anki_note_id`: `cards/` 配下からfrontmatterの `anki_note_id` が一致する問題カードをGrepで検索する

問題文やタグ等から更新対象を推測しない。

### Local card

対象カードをReadし、少なくとも次の項目を確認する。

- `id`
- `anki_note_id`
- `status`
- `note_type`

## Workflow

1. 指定された識別子から対象の問題カードを一意に特定する
2. 対象カードをReadして現在の内容と管理情報を確認する
3. `instruction` で指定された内容だけをローカル問題カードへ反映する
4. 更新後の問題カードがカード形式と品質条件を満たしていることを検証する
5. `sync_anki` の値に応じてAnki同期の要否を判定する
6. `sync_anki=true` の場合はAnki側の対象ノートを確認して変更内容を同期する
7. 処理結果に応じてローカルの `status` を更新する
8. 更新結果を検証する
9. 実行結果を報告する

## Local Update Rules

- `instruction` で明示された内容だけを変更する
- 指定されていない表現改善・内容追加・再生成を行わない
- 更新後も `card_format_reference.md` のデータ形式と品質条件を満たす
- `id` を変更しない
- `anki_note_id` を変更しない
- Anki登録済みの問題カードでは `note_type` を変更しない

### sync_anki=false

`sync_anki=false` の場合はAnkiMCPを使用せず、ローカル問題カードだけを更新する。

更新後の `status` は次のとおりとする。

- 未登録カードは `draft` を維持する
- Anki登録済みカードは `needs_sync` とする

## Anki Sync Rules

`sync_anki=true` の場合だけ、AnkiMCPを使用してローカルの変更内容をAnkiへ同期する。

### Target verification

- 対象カードに `anki_note_id` が存在することを確認する
- `anki_note_id` が存在しない場合はAnki同期を行わない
- 問題文・解答・タグ等からAnki Note IDを推測しない
- `notes_info` に保存済みの `anki_note_id` を渡して対象ノートを確認する
- Anki側の対象ノートがローカルカードの論理 `note_type` と対応関係の上で一致することを確認する

対象ノートを確認できない場合はAnkiへの更新を行わず、`status: needs_sync` として報告する。

論理型と実ノートタイプ名の対応は次のとおりとする。

- ローカル `Basic` ↔ Anki `Basic` または `基本`
- ローカル `Cloze` ↔ Anki `Cloze` または `穴埋め問題`

類似名のノートタイプを推測で一致扱いしない。たとえば `基本 コピー`、`基本 (裏表反転カード付き)` などは一致として扱わない。

### Field synchronization

`notes_info` で確認できる実際のフィールド名に合わせて同期する。想定外のフィールド構成の場合は推測せず同期を中止する。

Basicでは、変更対象に応じて次の標準フィールドだけを同期する。

- `front` → `Front` または `表面`
- `back` → `Back` または `裏面`

Clozeでは、変更対象に応じて次の標準フィールドだけを同期する。

- `text` → `Text` または `テキスト`
- `back_extra` → `Back Extra` または `裏面追記`

フィールドの同期には `update_note_fields` または `update_notes` を使用する。

変更されていないフィールドを意図なく書き換えない。

### Tag synchronization

ローカルの `tags` が `instruction` によって変更された場合だけ、`tag_management` を使用してAnki側へ変更内容を反映する。

対象Note IDを確認したうえで、必要なタグ変更だけを同期する。

### Synchronization result

Anki同期に成功した場合:

- `status` を `registered` とする

Anki同期に失敗した場合:

- ローカルで行った変更は元に戻さない
- `status` を `needs_sync` とする
- 同期に失敗した処理と原因を報告する

## Immutable Fields

次の項目は更新タスクで変更しない。

- `id`
- `anki_note_id`
- 登録済みカードの `note_type`

## Constraints

- 指定されていない問題カードを変更しない
- `instruction` に含まれない内容を変更しない
- Ankiへ新しいノートを追加しない
- Ankiノートを削除しない
- Ankiデッキを作成しない
- Ankiノートタイプを作成または変更しない
- Ankiノートタイプのフィールド構成を変更しない
- Ankiノートタイプのテンプレートまたはスタイルを変更しない
- `sync_anki=false` の場合はAnkiMCP Toolを使用しない
- Anki Note IDを問題内容から推測しない

## Output

処理完了後、次の内容を簡潔に返す。

- 更新対象のローカルID
- Anki Note ID
- ローカルで変更した項目
- Anki同期の実施有無
- Anki同期結果
- 更新後の `status`
- 警告または未処理事項
