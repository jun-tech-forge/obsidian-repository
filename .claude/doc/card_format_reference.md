# カード形式リファレンス

## 1. 基本方針

カード原本は `cards/` 配下に1カード1Markdownファイルで保存する。

Anki側では独自ノートタイプを作成せず、Anki標準のノートタイプをそのまま利用する。ローカルカード原本の `note_type` には論理名として `Basic` と `Cloze` だけを使用し、Anki上の実際の標準ノートタイプ名・フィールド名は表示言語に応じて解決する。標準ノートタイプへID等の独自フィールドも追加しない。

ローカルカード原本には、カード本文に加えてClaude Code側の管理情報を保持する。Anki登録時には必要な本文とタグだけをAnkiへ送信し、管理情報はVault内に留める。

---

## 2. Basicテンプレート

```markdown
---
id: it-20260901T044300-001
anki_note_id: null
status: draft
note_type: Basic
front: "HTTPのGETメソッドの主な用途は何か？"
back: |-
  リソースを取得すること。
  補足: 原則としてサーバー状態を変更しない安全な操作として扱う。
tags:
  - it::web_application::frontend
  - 難易度::基礎
  - 優先::高
source: notes/books/example.md
---
```

Anki登録時は、英語環境では次のように変換する。

```json
{
  "model_name": "Basic",
  "fields": {
    "Front": "HTTPのGETメソッドの主な用途は何か？",
    "Back": "リソースを取得すること。\n補足: 原則としてサーバー状態を変更しない安全な操作として扱う。"
  },
  "tags": [
    "it::web_application::frontend",
    "難易度::基礎",
    "優先::高"
  ]
}
```

- `front` は一問一答とする。
- `back` の1行目を主要解答とし、その後に1～2行の補足を置ける。
- 問いは50文字以内、主要解答は80字以内を目安とする。

---

## 3. Clozeテンプレート

```markdown
---
id: psychology-20260901T044300-001
anki_note_id: null
status: draft
note_type: Cloze
text: "ACTでは、思考を事実そのものではなく思考として捉える過程を{{c1::認知的フュージョン解除}}という。"
back_extra: |-
  補足: 思考の内容を消すのではなく、思考との関係を変えることを重視する。
tags:
  - psychology::acceptance_and_commitment_therapy
  - 難易度::基礎
  - 優先::中
source: notes/books/example.md
---
```

Anki登録時は、英語環境では次のように変換する。

```json
{
  "model_name": "Cloze",
  "fields": {
    "Text": "ACTでは、思考を事実そのものではなく思考として捉える過程を{{c1::認知的フュージョン解除}}という。",
    "Back Extra": "補足: 思考の内容を消すのではなく、思考との関係を変えることを重視する。"
  },
  "tags": [
    "psychology::acceptance_and_commitment_therapy",
    "難易度::基礎",
    "優先::中"
  ]
}
```

- Cloze記法はAnki標準の `{{c1::答え}}` を用いる。
- 1ノートの穴は最大3個とする。

---

## 4. ローカル管理項目

### 4.1 id

- Claude Code / Obsidian側でカード原本を識別するIDである。
- Ankiのフィールドには登録しない。
- デッキ内で一意とする。
- 推奨形式は `<deck>-YYYYMMDDTHHMMSS-NNN` とする。
- ファイル名を `<id>.md` とする。
- 一度付与したIDは更新タスクでも変更しない。

### 4.2 anki_note_id

- Ankiがノート追加時に発行するNote IDである。
- カード作成時は `null` とする。
- `add_notes` が `created` を返した場合、その戻り値の `note_id` を保存する。
- 更新・削除では、この値をAnki側ノートの主識別子として使用する。
- 一度登録された値を推測や再採番で置き換えない。

### 4.3 status

次の値を使用する。

- `draft`: 未登録。
- `registered`: Anki登録済みで、ローカル原本とAnkiの内容が同期している。
- `needs_sync`: 登録済みカードをローカルだけ更新し、Ankiへの同期が必要である。

### 4.4 note_type

- `Basic` または `Cloze` のみを許可する。
- Anki登録時に実際の `model_name` へ変換する管理情報であり、Ankiの独自フィールドとしては保存しない。
- `Basic` はAnki上の `Basic` または `基本`、`Cloze` はAnki上の `Cloze` または `穴埋め問題` に対応する。
- 登録済みカードの `note_type` は通常の更新タスクでは変更しない。

### 4.5 source

- 問題作成に使用したSourceノートの、Vaultルートからの相対パスである。
- 生成根拠の追跡用であり、Ankiのフィールドには登録しない。
- `notes/books/example.md` のような形式を標準とする。

---

## 5. カード本文

### 5.1 front / back

Basicで使用する。

- `front` は問いを一意に解釈できる形にする。
- `back` の主要解答は80字以内を目安とし、補足は1～2行とする。
- Anki登録時に `front` → `Front` または `表面`、`back` → `Back` または `裏面` へ変換する。

### 5.2 text / back_extra

Clozeで使用する。

- `text` は文脈自体に学習価値がある場合に用いる。
- `back_extra` は補足説明に用いる。
- Anki登録時に `text` → `Text` または `テキスト`、`back_extra` → `Back Extra` または `裏面補足` へ変換する。

---

## 6. Tags

次を含める。

- 分野タグ: `cards/` 以下のディレクトリ階層を `::` で連結したもの。
- 難易度: `難易度::基礎` または `難易度::応用`。
- 優先度: `優先::高`、`優先::中`、`優先::低`。

タグ内にスペースを入れない。分野ディレクトリは英小文字snake_caseを基本とする。

`tags` はAnkiのフィールドには変換せず、AnkiMCPのノートタグとして登録する。

---

## 7. 数式

- インライン: `\( 数式 \)`
- ブロック: `\[ 数式 \]`

---

## 8. 登録前検証

- 必須ローカル項目が存在する。
- `id` が今回処理する対象カード群内で重複しない。
- `id` が対象デッキ配下に既存するローカル原本の `id` とも重複しない。
- 未登録対象は `anki_note_id: null` かつ `status: draft` である。
- `note_type` がBasic/Clozeのいずれかである。
- `cards/` 配下の保存先ディレクトリ階層を `::` で連結した分野タグが、そのカードの `tags` に含まれる。
- 難易度・優先度タグが各1個である。
- タグにスペースがない。
- `source` のノートが存在する。
- Basicでは `front` と `back` が存在し、Cloze用項目を混在させない。
- Clozeでは `text` と `back_extra` が存在し、少なくとも1個、最大3個のCloze削除がある。
- 同一登録バッチ内でBasicの `front` またはClozeの `text` が重複しない。
- 文字数目安を超えた場合は警告し、著しく長い場合は登録を中止する。
- 対象カードに必要な論理 `note_type` について、対応する標準ノートタイプがAnki上に存在し、その実フィールド構成が `Front` / `Back`、`表面` / `裏面`、`Text` / `Back Extra`、`テキスト` / `裏面補足` のいずれかの想定どおりであることを `model_names` と `model_field_names` で確認する。類似名は一致扱いしない。
