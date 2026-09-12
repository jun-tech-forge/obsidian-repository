---
name: create-cards
description: Vault内の指定学習ノートから新しい暗記カード原本を作成する。Ankiへの登録や既存カードの変更は行わない。
disable-model-invocation: true
argument-hint: "source=<notes/...md> deck=<deck> tag=<cards/...> count=<目安件数>"
---

# Card Creation

## Inputs

`$ARGUMENTS` から次の値を取得する。

- `source`: 問題作成に使用するSourceノートのVault相対パス
- `deck`: 登録予定のAnkiデッキ名
- `tag`: 問題カードの保存先ディレクトリ
- `count`: 作成する問題数の上限目安

## References

処理を開始する前に、次の資料を読む。

- `.claude/doc/flashcard_workflow_spec.md` の問題作成タスクに関する章
- `.claude/doc/card_format_reference.md`

SourceノートをReadで読み込み、適用されるPath-specific rulesにも従う。

## Preconditions

カード作成前に、次の条件をすべて確認する。

- `source` が `notes/` 配下に存在するMarkdownファイルである
- `tag` が `cards/` 配下に存在するディレクトリである
- `deck` が `tag` の `cards/` 直下第1セグメントと一致する

条件を満たさない場合はカードを作成せず、問題を報告して終了する。

## Workflow

1. Readで `source` を読み込む
2. `tag` 配下の既存問題カードをGlobおよびGrepで確認する
3. Sourceノートからカード化する知識を抽出する
4. 各知識にBasicまたはClozeを割り当てる
5. 既存問題との重複を確認し、重複しない問題を作成する
6. 各問題に一意なローカルIDを採番する
7. `card_format_reference.md` に従って新しい問題カードを作成する
8. 作成結果を検証する
9. 実行結果を報告する

## Card Creation Rules

- `count` は作成件数の上限目安とし、十分な知識がない場合は無理に指定件数まで作成しない
- BasicとClozeの比率は概ね8:2を目安とするが、学習内容への適合性を優先する
- 同一の `front` または `text`、および明白な意味重複を作成しない
- `id` は `<deck>-YYYYMMDDTHHMMSS-NNN` 形式とし、deck内で一意にする
- ファイル名は `<id>.md` とする
- 新規カードの `anki_note_id` は `null` とする
- 新規カードの `status` は `draft` とする
- 問題カードは `<tag>/<id>.md` に新規作成する
- 問題カードは `card_format_reference.md` で定義されたYAML Front Matter形式に従う

## Constraints

- 既存の問題カードを変更または上書きしない
- 存在しない `tag` ディレクトリを作成しない
- 既存ファイルと同じパスへWriteしない
- Sourceノートに根拠のない情報を問題へ追加しない
- Ankiへの登録を行わない
- AnkiMCPを含むMCP Toolを使用しない

既存ファイルへの上書きが必要になる場合は、そのカードを作成せず報告する。

## Output

処理完了後、次の内容を簡潔に返す。

- 生成件数
- Basicの生成件数
- Clozeの生成件数
- 生成したファイル
- 警告または未処理事項
