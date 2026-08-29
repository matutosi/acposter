# 案C: acposter (学術ポスター PDF) 技術検討

## 1. 技術方式

- **build-abstract-pdf / build-slide-pdf と同一経路**: pandoc (md→HTML) + ヘッドレス Chrome (印刷) + CSS，LaTeX 不使用．3点構成 (ps1/css/lua) も踏襲．
- 相違点は「用紙が A0/A1 の巨大サイズ」「段組が本文全体に係る」の2点のみ．**pandoc への渡し方や Chrome 呼び出しコマンドは既存2スキルと共通化できる**ので，`make_poster_pdf.ps1` は両スキルのラッパー部分をほぼ流用し，差分は CSS の `@page` と段組指定に閉じ込める．
- 見出し (OBJECTIVES 等) の箱組みは lua フィルタで `# ` を `div.box` に変換する方式 (5節で詳述)．

## 2. A1/A0 サイズの実現

- **`@page { size: 841mm 1189mm; }` (A0 縦) のように mm 実寸を直接指定**．Chrome のヘッドレス印刷は `--print-to-pdf` 系で `paperWidth`/`paperHeight` をインチ指定するため，ps1 側で mm→inch 変換 (`/25.4`) して渡す．**CSS の `@page size` だけでなく Chrome 起動オプションの用紙寸法も一致させる**必要がある (既存2スキルは A4 なのでここは Chrome 既定に任せているはずだが，A0/A1 は非既定サイズなので明示指定が必須，かつズレると Chrome が既定 A4 に落ちて巨大な余白事故になる罠)．
- **フォントサイズは mm/pt ではなく `@page` 実寸に対する相対値 (`vw`/`vh` またはルート `%`) を基準にせず，固定 pt を使う**．理由: A0 は面積が A4 の16倍あり，「A4 に印刷しても読める」文字サイズは**A0 上での絶対 pt 値で決まる** (相対単位だと縮小時に予測しづらい)．目安は本文 24-28pt・見出し 40-48pt・表題 60-80pt (A0 縦，65%縮小して A4 相当で読める経験則)．**CSS 変数 (`--font-body`, `--font-heading`, `--font-title`) として `:root` に集約**し，A1 では A0比 70% (`calc()` で自動算出) にする．
- **Chrome の印刷スケーリングの罠**: `--print-to-pdf` はデフォルトで `scale=1` だが，`@page` の `size` と `--print-to-pdf-no-header` 等のフラグ組合せによっては**用紙外の要素を自動縮小 (shrink-to-fit) してしまう版がある**．これを避けるため，**CSS 側で `body` の実寸 (`width: 841mm` 等) を `@page` と一致させて明示**し，スケーリングに頼らずピクセル単位で1:1になるよう固定する．生成後に**PDF のページサイズを実測して mm 換算し @page 指定値と一致するか検算する** (8節と連動)．

## 3. 縦長・横長の切替

- `@page { size: <幅> <高さ> [landscape]; }` を CSS 変数化し，ps1 の `-Orientation portrait|landscape` 引数で幅・高さを入れ替える (`--page-size A0 -Orientation landscape` のように既存スキルの `-PageSize` 引数の命名慣習に合わせる)．
- A0/A1 × 縦/横の4通りを `poster.css` 内の `@page` 定義テーブル (mm 値のマップ) として保持し，ps1 が該当値を lua/CSS 生成時に埋め込む．

## 4. 段組みの実装

- **タイトル部**: `div.title-block` に `column-count: 1` を明示 (通常は1段組が既定なので上書き不要だが，本文の `columns` の親スコープと分離するため明示する)．
- **本文**: `div.body { columns: 2; column-gap: 12mm; column-rule: 0.5mm solid transparent; }` で2段組．CSS `columns` は pandoc の生 HTML では**段抜け (box が段の途中で割れる)** が起きやすいので，各見出しボックス (`div.box`) に **`break-inside: avoid`** を必須で付与．
- **多段組**: `-Columns 3` のような ps1 引数で `column-count` を変数化 (CSS 変数 `--columns`)．
- **部分的1段組**: 見出し (`# `) ごとに lua が `div.box` を作る際，**md 側で `{.span-all}` 属性を見出しに付けられるようにし**，該当 box だけ `column-span: all` を付与する設計 (pandoc の attribute 記法 `# BACKGROUNDS {.span-all}` はネイティブに解釈できるため実装コストが低い)．これで「部分的に1段組」も可能．
- 引数設計案:
  | 引数 | 既定 | 役割 |
  |---|---|---|
  | `-PageSize A0\|A1` | A0 | 用紙 |
  | `-Orientation portrait\|landscape` | portrait | 向き |
  | `-Columns 2` | 2 | 本文の段数 |
  | `-FontSize` | (体裁テーブルの既定値) | 本文文字サイズ上書き |

## 5. 緑角丸枠見出し (BOX) の再現

- lua フィルタで **`Header` (レベル2程度) を検出し，その見出しから次の同レベル見出しまでのブロック群を `div.box` でラップし，見出し文字列を `div.box-title` として先頭に置く** 設計．build-slide-pdf の「`# ` を1枚に分割する」ロジック (`# ` 区切りで塊にする) と同じ考え方の応用なので実装パターンを転用できる．
- CSS: `div.box { border: 2px solid #1a7a3c; border-radius: 10px; padding: ...; break-inside: avoid; margin-bottom: ...; }`，`div.box-title { background: #1a7a3c; color: #fff; border-radius: 6px; display: inline-block; padding: 0.2em 1em; }` で見本の「濃い緑の角丸ラベル + 緑の角丸枠」を再現．色は CSS 変数 `--box-color: #1a7a3c` として1箇所に集約 (9節と関連: 依存追加なしで色替え可能にする)．
- box 内が2段組の片方の列内で完結するよう `break-inside: avoid` は必須．box が段の高さを超える場合はページからあふれるので，8節の検算で検出する．

## 6. 画像記法の扱い

- ユーザ原文の `[メモ](filename.png)` は **リンク記法であり画像記法 `![メモ](filename.png)` の書き誤りと判断**して設計する (明記: この前提を採用)．ただし **lua フィルタで `Link` ノードのうち `target` が画像拡張子 (`.png`/`.jpg`/`.svg` 等) のものを自動的に `Image` へ読み替える救済処理を入れる**．これによりユーザが `!` を付け忘れても正しく図として出る (書き間違いを許容する設計．要件根本の解釈違いリスクをヘッジ)．
- build-slide-pdf の罠 (`p` に包まれると `img { max-height: 100% }` が効かない) を踏まえ，**`div.fig > img` 構造を lua で強制**する同じ対策を poster.lua でも行う．ポスターは2段組の列幅に収める必要があるため，`div.fig img { max-width: 100%; height: auto; }` を基本にし (スライドの「残り高さいっぱい」ではなく「列幅いっぱい」が基準になる点が相違)，box 内での画像は `break-inside: avoid` を親 box に掛けているため追加対応は不要．
- 画像キャプションは `![キャプション](path)` の alt を使う場合と使わない場合が要件からは不明なため，**既定はキャプション非表示 (`-implicit_figures` を切る，slide.lua と同じ)** とし，必要なら `-Caption on` で表示に切替可能にする設計を提案．

## 7. ファイル構成案

```
~/.claude/skills/build-poster-pdf/
├── SKILL.md
├── make_poster_pdf.ps1   # pandoc→Chrome 呼び出し。用紙寸法をmm→inch変換して渡す。ページ実寸・フォント埋め込み・box列内包を検算
├── poster.css             # @page(A0/A1×縦横テーブル)・CSS変数(色・フォント・段数)・box(緑角丸)・段組・画像
└── poster.lua             # 見出し→div.box変換、リンク→画像の読み替え、div.fig>img構造の強制、表題・著者行の自動生成
```

- 体裁ファイル探索順序 (プロジェクト側優先→スキル同梱) は既存2スキルと同一パターンを踏襲．
- YAML ヘッダーのキー (`title`/`author`/`institute`/`type`/`date`) も既存踏襲，`type: "学術ポスター"` で判別．

## 8. 出力後の検算項目

- **ページ数**: 通常1ページのはず．2ページ以上になったら box があふれた警告として報告 (build-slide-pdf のページ数検算パターンを流用)．
- **用紙実寸**: PDF のページサイズ (pt) を mm に換算し，指定した A0/A1×向きと一致するか (既存の「用紙の向き」検算を拡張し，**寸法値そのもの**まで照合する．3節の Chrome スケーリング罠対策)．
- **フォント埋め込み**: 既存2スキルと同じ `/BaseFont` 検算．
- **段組崩れの検出**: 機械的な完全検出は難しいが，**中間 HTML を Chrome で開き，各 `div.box` の `getBoundingClientRect()` が `@page` の版面内 (0 〜 版面高さ) に収まっているかを JS で走査するスクリプトを ps1 に組み込む** (build-abstract-pdf のぶら下げ検算で使った「座標を測る」手法の応用)．収まっていない box があれば box 名とはみ出し量を報告する．
- **段の列数の視認**: `div.body` の `column-count` が計算値どおりに適用されているかを `getComputedStyle` で確認 (Chrome の columns 実装のブラウザ差異を早期検出)．

## 9. 依存ツール一覧

- pandoc・Chrome (or Edge)・フォント (UD デジタル教科書体 N 等，既存踏襲) — **これ以外は不要**．
- LaTeX・R・追加の npm パッケージ・PDF 編集ライブラリはいずれも**不要** (CSS `columns` と `@page` サイズ指定は Chrome ネイティブ機能のみで実現できるため)．

---

## この案の要点 (3行以内)

既存2スキルと同じ pandoc+Chrome+CSS 経路をそのまま流用し，差分は `@page` の mm 実寸指定 (A0/A1×縦横) と CSS `columns` 段組・`div.box` 緑角丸見出しに閉じ込める．A0/A1 の巨大文字は pt 絶対値の CSS 変数で一元管理し，Chrome の用紙スケーリング事故を防ぐため生成後に PDF 実寸と box のはみ出しを機械検算する．画像記法の書き誤りはリンク→画像への lua 救済で吸収し，依存ツールは pandoc・Chrome・フォントのみで増やさない。
