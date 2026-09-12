# AnkiMCP 参考ドキュメント

## 1. 対象

本プロジェクトでいうAnkiMCPは、AnkiWebアドオンコード `124672614` の **Anki MCP Server Addon** を指す。AnkiConnectを直接利用する別実装とは区別する。

既定構成ではAnki内でローカルHTTP MCPサーバーが起動し、`127.0.0.1:3141` を使用する。Ankiを起動し、アドオンが有効であることが登録処理の前提となる。

---

## 2. 本処理で使用するTool

### 2.1 読み取り・事前確認

- `list_decks`: デッキ一覧を取得し、登録先の存在確認に使用する。
- `model_names`: 利用可能なノートタイプを取得し、標準 `Basic` / `Cloze` の存在確認に使用する。
- `model_field_names`: ノートタイプのフィールド名を確認する。`Basic` は `Front` / `Back`、`Cloze` は `Text` / `Back Extra` を期待する。
- `find_notes`: Anki検索構文でノートを検索する。ローカルメタデータが欠損した場合の重複調査等に使用する。
- `notes_info`: Note IDを指定してノート詳細を取得する。更新・削除前に対象ノートの存在とノートタイプを確認する用途、および登録後の確認に使用する。

### 2.2 新規登録

- `add_note`: 1件のノートを追加できるが、本処理の標準登録経路では使用しない。
- `add_notes`: 同一デッキ・同一ノートタイプのノートを一括追加する。1件でも利用でき、既定 `max_notes_per_batch` は100である。本処理の標準登録Toolとする。

`add_notes` は次の主要引数を持つ。

```text
deck_name: 登録先デッキ名
model_name: 使用するノートタイプ名
notes: fieldsとtagsを持つノート配列
tags: 全ノートへ共通付与する任意タグ
allow_duplicate: 既存重複を許可するか。本処理ではfalse
```

各 `notes` 要素は概ね次の構造を持つ。

```json
{
  "fields": {
    "Front": "質問",
    "Back": "回答"
  },
  "tags": ["it::python", "難易度::基礎", "優先::高"]
}
```

`add_notes` は成功・スキップ・失敗の件数に加え、入力配列のindexごとの結果を返す。成功した要素は `status: created` とAnkiの `note_id` を含む。この `note_id` をローカルカードの `anki_note_id` として保存する。

`allow_duplicate=false` の場合、既存コレクションに対してノートタイプの第1フィールドで重複判定する。標準Basicでは `Front`、標準Clozeでは `Text` が対象となる。ただし同一 `add_notes` バッチ内の重複はAnkiMCP側では検出しないため、Claude Code側の事前検証が必要である。

### 2.3 明示的な更新時のみ使用

- `update_note_fields`: `anki_note_id` で特定した既存ノートのフィールドを更新する。
- `update_notes`: 複数ノートのフィールドを一括更新する。
- `tag_management`: 明示的なタグ変更をAnkiへ同期する場合に使用する。

### 2.4 削除タスクでのみ使用

- `delete_notes`: Note IDを指定してノートを削除する。

`delete_notes` は次の主要引数を持つ。

```text
notes: 削除対象のNote IDの配列
```

削除対象には、カード原本の `anki_note_id` で一意に特定したNote IDだけを渡す。問題文やタグからの検索結果を推測で渡してはならない。

通常の作成・登録・更新タスクからは削除を実行しない。削除は問題削除タスク（`/delete-cards`）でのみ実行し、削除前に `notes_info` で対象ノートの存在を確認する。

### 2.5 本プロジェクトで使用しないスキーマ変更Tool

- `create_model`
- `model_fields`
- `update_model_templates`
- `update_model_styling`
- `change_note_type` 相当のノートタイプ変更処理

本プロジェクトはAnki標準 `Basic` / `Cloze` を無変更で使用するため、ノートタイプ作成・フィールド追加・テンプレート変更を通常処理にも初期セットアップにも含めない。

---

## 3. 標準ノートタイプへの登録

### 3.1 Basic

ローカルカードから次だけを送信する。

```json
{
  "deck_name": "it",
  "model_name": "Basic",
  "notes": [
    {
      "fields": {
        "Front": "質問",
        "Back": "回答"
      },
      "tags": ["it::web_application::frontend", "難易度::基礎", "優先::高"]
    }
  ],
  "allow_duplicate": false
}
```

### 3.2 Cloze

```json
{
  "deck_name": "it",
  "model_name": "Cloze",
  "notes": [
    {
      "fields": {
        "Text": "HTTPの{{c1::GET}}は主にリソース取得に使う。",
        "Back Extra": "補足説明"
      },
      "tags": ["it::web_application::frontend", "難易度::基礎", "優先::高"]
    }
  ],
  "allow_duplicate": false
}
```

`id`, `anki_note_id`, `status`, `note_type`, `source` はAnkiMCPのfieldsへ渡さない。

---

## 4. Note IDによる識別

Ankiへ追加されたノートにはAnki内部のNote IDが付与される。ローカルの `id` とは別物である。

```text
ローカル id
it-20260901T044300-001
        ↓ 対応
Anki Note ID
xxxxxxxxxxxxx
```

新規登録時は `add_notes` の成功結果からNote IDを直接取得し、カードMarkdownへ保存する。以後の更新は `anki_note_id` → `notes_info` → `update_note_fields` の順で対象を確認してから実施する。削除も同様に `anki_note_id` → `notes_info` → `delete_notes` の順で対象を確認してから実施する。

Front/Textだけを恒久的な識別子として使用しない。問題文は更新で変化し得るためである。

---

## 5. 接続確認

```powershell
claude mcp list
claude mcp get anki
```

`anki` はユーザースコープの `~/.claude.json` ではなく、本プロジェクト専用のMCPサーバーとしてプロジェクトルートの `.mcp.json` に定義する。`.claude/settings.json` の `enabledMcpjsonServers` に `anki` を含めることで、`claude mcp add` によるユーザースコープへの個別追加なしに自動承認される。

---

## 6. 参考URL

- AnkiWeb Add-on: https://ankiweb.net/shared/info/124672614
- AnkiMCP Server Addon: https://github.com/ankimcp/anki-mcp-server-addon
- Claude Code MCP: https://code.claude.com/docs/en/mcp
