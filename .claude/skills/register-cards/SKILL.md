---
name: register-cards
description: 指定した問題カード原本を検証し、Anki標準のBasicまたはClozeとしてAnkiMCPで新規登録する。登録成功後は対応するローカル管理メタデータだけを更新する。
disable-model-invocation: true
argument-hint: "path=<cards/...md または cards/.../> deck=<Ankiデッキ名>"
---

# Card Registration

## Inputs

`$ARGUMENTS` から次の値を取得する。

- `path`: 登録対象の問題カードファイルまたはディレクトリ
- `deck`: 登録先のAnkiデッキ名

## References

処理を開始する前に、次の資料を読む。

- `.claude/doc/flashcard_workflow_spec.md` の問題登録タスクに関する章
- `.claude/doc/card_format_reference.md`
- `.claude/doc/ankimcp_reference.md`

## Preconditions

Ankiへの書き込みを開始する前に、次の条件をすべて確認する。

PowerShellスクリプト側で、`path` が `cards/` 配下の実在するファイルまたはディレクトリであることは検証済みである前提で処理する。

### Local cards

- `path` がファイルの場合、そのファイルを登録対象の問題カードとしてReadできる
- `path` がディレクトリの場合、その配下から登録対象の問題カードを列挙できる
- 必須項目が存在する
- `id` が対象内で重複していない
- `note_type` が `Basic` または `Cloze` である
- Basicに `front` と `back` が存在する
- Clozeに `text` と `back_extra` が存在する
- Cloze記法が仕様上の制約を満たしている
- 分野タグと保存先パスが一致する
- 難易度タグと優先度タグが仕様を満たしている
- `source` が示すSourceノートが存在する
- `status` と `anki_note_id` の組み合わせに矛盾がない

`path` がディレクトリで、列挙結果が0件の場合は、`path` が存在しないとは判断せず、登録対象の問題カードが存在しないものとして扱う。

ローカル構造エラーが1件でも存在する場合は、Ankiへの書き込みを開始せず終了する。

### Anki

AnkiMCPを使用して、次の条件を確認する。

- `list_decks` で `deck` が存在する
- `model_names` で対象カードに必要な `Basic` または `Cloze` が存在する
- `model_field_names` でBasicのフィールドが `Front` と `Back` である
- `model_field_names` でClozeのフィールドが `Text` と `Back Extra` である

期待するデッキ・ノートタイプ・フィールド構成が存在しない場合は、自動作成または自動変更せず終了する。

## Workflow

1. `path` から対象の問題カードを列挙してReadする
2. 全対象についてローカル構造検証を行う
3. AnkiMCPで登録先デッキ・ノートタイプ・フィールド構成を確認する
4. 登録済みの問題カードを処理対象から除外する
5. 登録対象内の問題文重複を確認する
6. 未登録の問題カードをAnkiMCP入力形式へ変換する
7. 登録対象を `deck` と `note_type` ごとにグループ化してバッチ分割する
8. `add_notes` で各バッチをAnkiへ登録する
9. 各登録結果を入力問題カードと対応付ける
10. 登録成功した問題カードの `anki_note_id` と `status` を更新する
11. 登録結果を検証する
12. 実行結果を報告する

## Registration Rules

### Registration target

- `status: registered` かつ `anki_note_id` が存在する問題カードは登録済みとして処理対象から除外する
- `status` と `anki_note_id` が矛盾する問題カードは自動登録せずエラーとして扱う
- Basicでは同一の `front`、Clozeでは同一の `text` が登録対象内で重複しないことを確認する

### Field mapping

Basicは次のように変換する。

- `front` → `Front`
- `back` → `Back`
- `tags` → Ankiネイティブタグ

Clozeは次のように変換する。

- `text` → `Text`
- `back_extra` → `Back Extra`
- `tags` → Ankiネイティブタグ

次のローカル管理情報はAnkiのfieldsへ渡さない。

- `id`
- `anki_note_id`
- `status`
- `note_type`
- `source`

### Batch registration

- BasicとClozeを同一の `add_notes` 呼び出しへ混在させない
- 1バッチはAnkiMCPの `max_notes_per_batch` 以下とする
- 既定の上限は100件として扱う
- 100件を超える場合は複数バッチへ分割する
- 件数にかかわらず `add_notes` を使用する
- 1件の場合も1要素のバッチとして登録する
- `allow_duplicate` は必ず `false` とする

### Registration result

`add_notes` の各結果を入力indexと対応付けて処理する。

`status: created` の場合:

- 返された `note_id` を対応する問題カードの `anki_note_id` へ保存する
- ローカルの `status` を `registered` へ変更する

`status: skipped` または `status: failed` の場合:

- `anki_note_id` を推測して保存しない
- ローカルの登録状態を成功扱いへ変更しない
- 必要に応じて `find_notes` または `notes_info` で状況を確認する
- 既存Ankiノートとの対応を一意に確認できない場合は、利用者による確認が必要であることを報告する

## Mutable Fields

登録タスクで変更できるローカル項目は、登録成功した問題カードの次の2項目だけとする。

- `anki_note_id`
- `status`

次の項目は変更しない。

- `id`
- `note_type`
- `front`
- `back`
- `text`
- `back_extra`
- `tags`
- `source`

## Constraints

- 問題カードの内容を登録処理中に修正しない
- Ankiデッキを新規作成しない
- Ankiノートタイプを新規作成または変更しない
- Ankiノートタイプのフィールド構成を変更しない
- Ankiノートタイプのテンプレートまたはスタイルを変更しない
- 既存のAnkiノートを更新しない
- 既存のAnkiノートを削除しない
- `update_note_fields` を使用しない
- `update_notes` を使用しない
- `delete_notes` を使用しない
- `create_deck` を使用しない
- `change_note_type` を使用しない
- `create_model` を使用しない
- ノートタイプのフィールド・テンプレート・スタイルを変更するToolを使用しない

## Output

処理完了後、次の内容を簡潔に返す。

- 登録成功件数と対象ローカルID・Anki Note ID
- 登録済みとして処理対象外にした件数とローカルID
- 重複により登録されなかった件数とローカルID
- 登録失敗件数とローカルID
- 失敗理由または利用者による確認が必要な事項
