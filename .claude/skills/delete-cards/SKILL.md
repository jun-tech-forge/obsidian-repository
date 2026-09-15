---
name: delete-cards
description: 明示指定された既存問題カードについて、必要に応じてAnki側のノートを削除した後、Vault側の問題カードファイルを削除する。対象はファイルパス・ローカルID・Anki Note IDのいずれかで指定する。
disable-model-invocation: true
argument-hint: "path=<cards/...md>[,...] | id=<local-id>[,...] | anki_note_id=<note-id>[,...]"
---

# Card Deletion

## Inputs

`$ARGUMENTS` から次のいずれか1種類の識別子を取得する。

- `path`: 削除対象の問題カードファイル
- `id`: 削除対象のローカルID
- `anki_note_id`: 削除対象のAnki Note ID

識別子の値はカンマ区切りで複数指定できる。複数指定された場合は、各値を独立した削除対象として処理する。

## References

処理を開始する前に、次の資料を読む。

- `.claude/doc/flashcard_workflow_spec.md` の問題削除タスクに関する章
- `.claude/doc/card_format_reference.md`
- `.claude/doc/ankimcp_reference.md`

## Preconditions

削除処理を開始する前に、次の条件を確認する。

### Identifier

- `path`, `id`, `anki_note_id` のうち指定されている識別子が1種類だけである
- 0種類または2種類以上指定されている場合はタスク全体を終了する
- ディレクトリまたはワイルドカードによる削除指定ではない

### Target identification

識別子ごとに、`cards/` 配下から対象の問題カードを特定する。

- `path`: 指定された問題カードファイルを対象とする
- `id`: `cards/` 配下から `<id>.md` をGlobで検索する
- `anki_note_id`: `cards/` 配下からfrontmatterの `anki_note_id` が一致する問題カードをGrepで検索する

各指定値について、対象を単一の問題カードへ一意に特定できることを確認する。

該当する問題カードが0件または複数件の場合は、その指定値の削除処理を行わず理由を報告する。

問題文・解答・タグ等から削除対象を推測しない。

### Local card

対象カードをReadし、少なくとも次の項目を確認する。

- `id`
- `anki_note_id`
- `status`
- `note_type`

登録状態とAnki Note IDの整合性を確認する。

- `status: draft` の場合は `anki_note_id: null` である
- `status: registered` または `status: needs_sync` の場合は `anki_note_id` が存在する

状態に矛盾がある場合は、自動的に補正または推測せず、その指定値の削除処理を終了する。

## Workflow

各削除対象について、次の順序で処理する。

1. 指定された識別子から対象の問題カードを一意に特定する
2. 対象カードをReadして管理情報を確認する
3. Anki側の削除が必要か判定する
4. Anki Note IDが存在する場合はAnki側の対象ノートを確認する
5. 対象ノートが存在する場合はAnkiから削除する
6. Anki側の削除完了または削除不要を確認する
7. 対応するローカル問題カードファイルだけを削除する
8. 削除結果を検証する
9. 実行結果を報告する

## Anki Deletion Rules

### Unregistered card

`anki_note_id` が `null` の場合は、Anki側の削除を行わない。

Anki未登録であることを確認した後、ローカル問題カードの削除へ進む。

### Registered card

`anki_note_id` が存在する場合は、その値だけを使用してAnki側の対象ノートを特定する。

- `notes_info` に保存済みの `anki_note_id` を渡す
- 対象ノートが存在する場合は、ローカルカードの論理 `note_type` と対応関係の上で一致することを確認する
- 問題文・解答・タグ等からAnki Note IDを推測しない

対象ノートが存在する場合は、`delete_notes` に確認済みの `anki_note_id` だけを渡して削除する。

論理型と実ノートタイプ名の対応は次のとおりとする。

- ローカル `Basic` ↔ Anki `Basic` または `基本`
- ローカル `Cloze` ↔ Anki `Cloze` または `穴埋め問題`

類似名のノートタイプを推測で一致扱いしない。たとえば `基本 コピー`、`基本 (裏表反転カード付き)` などは一致として扱わない。

### Anki note already deleted

`notes_info` で対象ノートが見つからない場合は、Anki側のノートは既に削除済みとして扱う。

この場合は警告を記録したうえで、ローカル問題カードの削除へ進む。

### Anki deletion failure

`delete_notes` の呼び出しに失敗した場合は、対応するローカル問題カードを削除しない。

失敗した対象と原因を報告し、その指定値の処理を終了する。

## Local Deletion Rules

ローカル問題カードを削除できるのは、次のいずれかを確認できた場合だけとする。

- Anki未登録の問題カードである
- Anki側の対象ノートを正常に削除できた
- Anki側の対象ノートが既に存在しない

削除対象は、事前に一意に特定した1つの問題カードファイルだけとする。

他のファイルやディレクトリを削除対象に含めない。

複数の指定値がある場合も、各対象を独立して検証・削除する。

## Constraints

- 指定されていない問題カードを削除しない
- ディレクトリ単位で削除しない
- ワイルドカードによる一括削除を行わない
- 問題文・解答・タグ等から削除対象を推測しない
- Ankiへ新しいノートを追加しない
- Ankiノートのフィールドを更新しない
- Ankiノートのタグを変更しない
- Ankiデッキを作成または削除しない
- Ankiノートタイプを作成または変更しない
- Ankiノートタイプのフィールド構成を変更しない
- Ankiノートタイプのテンプレートまたはスタイルを変更しない
- Anki側の削除結果を確認する前にローカル問題カードを削除しない

## Output

処理完了後、指定値ごとに次の内容を簡潔に返す。

- 指定された識別子と値
- 対応するローカルID
- Anki Note ID
- Anki側の削除結果
- ローカル問題カードの削除結果
- 処理結果
- 失敗理由または警告
