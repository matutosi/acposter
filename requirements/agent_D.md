# 案D: acposter (学術ポスター PDF ビルド) 設計

見本 PDF (`poster.pdf`) を確認．A1想定の縦長ポスターで，上部に緑帯タイトル (氏名・所属・注記を内包)，本文は緑の角丸枠見出し (OBJECTIVES/CONCLUSIONS/BACKGROUNDS/RESULTS/METHODS) が**左上から時計回りではなく，左列上から OBJECTIVES→BACKGROUNDS→METHODS，右列上から CONCLUSIONS→RESULTS** という「2列それぞれが独立に上から流れる」配置．単純な段組み流し込みでは再現できない (右列先頭が CONCLUSIONS で左列より短い上に，下段 SUMMARY と Dominant species は全幅) ことが要点．

## 1. 技術方式

- 基本方針どおり **pandoc + ヘッドレス Chrome + CSS 印刷**を採用．LaTeX 不使用．
- 既存2スキルとの共通点: `ps1` ラッパー (pandoc→Chrome→検算) / `css` (体裁) / `lua` (構造変換) の3点構成，体裁ファイルの探索順 (原稿ディレクトリ→`build/`→スキル同梱)．
- 相違点: build-abstract-pdf は「流し込み文書」，build-slide-pdf は「`# ` 区切りの直列カード」．acposter は**「見出しごとの矩形ボックスを、ページ上の任意位置 (grid-area) へ配置する」**必要があり，単純な段組み (CSS multi-column) だけでは要件5 (配置順序の自由) を満たせない．よって本文全体は **CSS Grid** で構成し，各 `## ` セクションを **grid item (ボックス)** として扱う．段組み (2段/多段/部分1段) は Grid の列指定そのもので表現する (別項6参照)．

## 2. A1/A0 サイズの実現

- `@page { size: 841mm 1189mm; }` (A0 縦) / `594mm 841mm` (A1 縦) を `-Size A0|A1` 引数で切替．Chrome の `print-to-pdf` はミリ単位の任意サイズを扱えるので追加ツール不要．
- フォントサイズは **A4 基準 pt 値に倍率を掛けて算出**する方式にする: A1 は A4 の√2倍 (面積2倍×2回) 相当ではなく，実務的には「A4で作った文面をそのまま拡大コピーしたときに読める大きさ」を基準に，倍率 A1=2.83倍・A0=4.0倍を既定係数として `html { font-size: calc(10.5pt * var(--scale)) }` のように CSS 変数で一括制御する．
- 可読性担保: 検算で「本文フォントの実寸 (mm換算)」を表示し，**7mm未満で警告** (学会ポスターの目安である体格2m離れて可読 = 本文18-24pt相当を A0 実寸で換算した値) を出す．A4 縮小プレビュー用に `-Preview A4` で別途 A4 版 PDF も出せるようにする (同じ HTML を `@page` だけ変えて再印刷，文字は自動縮小されるので目視確認用途).

## 3. 縦長・横長 (Landscape) の切り替え

- `-Orientation portrait|landscape` 引数で `@page` の `size` の縦横を入れ替え，Grid の `grid-template-columns`/`grid-template-areas` も向きに応じて別定義を持たせる (CSS の `@page` 単体では Grid レイアウトまで自動追随しないため，lua 側で向きを HTML の `<body data-orientation="...">` に埋め込み，CSS で `[data-orientation="landscape"] .content { grid-template-areas: ... }` を分岐).
- 既定は縦長 (portrait)．YAML ヘッダーの `orientation:` でも指定可 (引数が優先).

## 4. 段組みの実装

- **タイトル部**: Grid の最上段1行を `grid-column: 1 / -1` (全幅) で1段固定．ここは lua がヘッダーから自動生成 (既存2スキルと同じ思想).
- **本文の既定**: `grid-template-columns: 1fr 1fr` の2段．
- **多段対応**: YAML `columns: 3` のように列数を指定できる引数/ヘッダーキーを追加 (`-Columns 3` / ヘッダー `columns: 3`).
- **部分的な1段組み (全幅ボックス)**: 各セクションに `span: full` を明示できる記法を用意 (見出し行に注記，または YAML の `layout:` リストで指定．詳細は5・後述の柔軟性の項).
- 見本のように「下段 SUMMARY・Dominant species は全幅」を再現するため，**セクション単位で `grid-column: span N` を個別上書きできる**必要がある．これは CSS の `columns` プロパティ (雑誌調の自動流し込み) では実現不可能なので Grid 必須．

## 5. 緑角丸枠見出し (BOX 見出し) の再現

- `## ` 見出し1つ = 1ボックス，という設計を採用 (提案どおり).
- lua フィルタで `## 見出し文字列` を検出し，`<div class="box"><div class="box-title">見出し</div><div class="box-body">...本文...</div></div>` に変換．次の `## ` または `# `/文書末までを本文として囲い込む (build-slide-pdf の「`# ` ごとに切り分ける」ロジックを流用可能).
- CSS: `.box-title` は緑地・白文字・角丸上部のみ (見本は見出し帯が上に角丸で乗っている形)，`.box` 全体に緑の角丸枠線 (`border-radius`, `border: 3px solid green`).
- 色は CSS 変数 `--box-color: #1a7a3c` のように1箇所で管理し，学会によって色を変える運用に対応 (プロジェクト側 css で上書き可能，既存2スキルと同じ思想).

## 6. 画像記法の扱いとlua フィルタ設計

- ユーザ原文の `[メモ](filename.png)` は pandoc 記法としては**リンク**であり画像挿入にならない．標準記法 `![caption](filename.png)` の書き間違いと判断し，**画像記法は標準 `![alt](path)` を前提**とする (この判断を README/SKILL.md に明記し，`[text](xxx.png)` 形式が来た場合は lua で警告メッセージを出す防御的処理を入れる: 拡張子が画像であるのにリンクノードのままなら stderr 相当の警告を出し，自動で画像化はしない=誤爆防止).
- build-slide-pdf の罠 (`div.fig > img` にするため `p` を外す) をそのまま踏襲: ポスターは画像を多用するため，画像単体段落は `<div class="fig"><img></div>` に変換し `p` で包まない．
- ポスター特有の追加要件: **画像の複数枚並び (見本の Backgrounds セクション内の6枚組、Dominant species の4枚組)** に対応するため，`::: figrow` ... `:::` のような fenced-div 記法を lua で拾い，`display:flex; flex-wrap:wrap` の行に変換する (build-book-pdf の `::: figpair :::` と同じ発想の拡張).
- 表 (RESULTS の集計表・occurrence 表) はそのまま pandoc の表変換に任せ，box 内で `overflow: hidden` にせず `font-size` を自動縮小するクラス (`.dense-table`) を用意する (build-slide-pdf の `.small`/`.xsmall` と同じ考え方を表にも適用).

## 7. ファイル構成案

```
~/.claude/skills/build-poster-pdf/
  SKILL.md
  make_poster_pdf.ps1   # pandoc → Chrome 呼び出し、Size/Orientation/Columns 引数、検算
  poster.css            # @page, Grid既定, box見出し, 画像/表の詰め
  poster.lua            # 表題ブロック生成、##→box変換、layout指定の適用、画像/figrow処理、p剥がし
```
- 命名は `build-poster-pdf` とし，既存2スキルの命名規則 (`build-<種別>-pdf`) に揃える．
- プロジェクト側 (`acposter/` や個別学会ディレクトリ) で `poster.css`/`poster.lua` を上書きできる探索順を既存2スキルと同一にする．

## 8. 出力後の検算項目

- **ページ数** (ポスターは1ページのはずなので「1ページであること」を確認．2ページ化=あふれの signal).
- **フォント埋め込み** (既存と同じ `/BaseFont` 抽出方式を流用).
- **用紙サイズ・向きが指定どおりか** (`mediabox` を PDF から読み検算).
- **段崩れ検出**: 各 box の HTML 上の bounding box を Chrome の DOM 計測 (中間 HTML を開いて `getBoundingClientRect` を打鍵) で取得し，ページ矩形からのはみ出し (`bottom > page-height` など) を機械的に検出して警告 (build-abstract-pdf の「ぶら下げ揃えの座標確認」と同発想を自動化まで進める).
- **本文文字の実寸 (mm)** を A1/A0 換算で表示し，可読性の目安を下回れば警告 (項目2参照).

## 9. 依存ツール一覧

- pandoc・Chrome (or Edge)・フォント (UD デジタル教科書体 N 等，既存踏襲) — **これ以外は不要**．
- 画像複数枚の並び・表縮小・Grid 配置はすべて CSS/lua で完結するため，追加のツール (ImageMagick 等) は不要．

## 柔軟性の重点検討: セクション順序とレイアウト指定

原稿の書きやすさ・保守性を最優先し，**素の md では上から下へ書く自然な執筆順を保ちつつ，配置だけを別途指定できる二層構造**を提案する．

- **既定 (指定なし)**: `## ` の出現順に，Grid の「行優先ではなく列優先」で自動流し込みする (左列を上から埋め，あふれたら右列，という新聞的な流し込み)．これなら原稿は単純に上から書けば良く，保守性が高い (見出しを増減・入れ替えても事故が起きにくい).
- **配置を明示したいとき**: YAML ヘッダーに `layout:` リストを追加できる任意項目とする．

```yaml
layout:
  - [OBJECTIVES, CONCLUSIONS]
  - [BACKGROUNDS, RESULTS]
  - [METHODS, RESULTS]
  - [SUMMARY]        # 全幅 (1要素の行 = span full)
  - [DOMINANT SPECIES]
```

  各行が Grid の1行，行内の要素数がその行の列分割 (2要素なら2段，1要素なら全幅) に対応．**見出し文字列と `## ` の本文側の見出しを名前で対応させる**ので，本文の執筆順序と `layout` の配置順序が分離でき，「本文は書きやすい順で書き，配置だけ後から調整する」運用に耐える．
- `layout` 省略時は自動流し込み，指定時のみ Grid Areas を厳密に組む，という**2段階のフォールバック**にすることで，初稿段階 (配置未確定) では何も考えず書け，仕上げ段階でだけ `layout` を足す，という執筆サイクルに合致させる．
- 見出し名の**表記ゆれ**(全角/半角，大文字/小文字)は lua 側で正規化して突き合わせ，`layout` にあって本文に無い・本文にあって `layout` に無い見出しはエラーで止める (検算の一種．取りこぼしは user CLAUDE.md の運用ルールとも整合).
- この設計により，`grid-template-areas` を直接 CSS 的に書かせる (アルファベットの区画名を手打ちさせる) よりも，**見出し文字列そのものを配置指定に使える**ため原稿と設定の対応が読みやすく，差し替え時の事故が起きにくい．

## この案の要点 (3行以内)

pandoc+Chrome+CSS Grid で `## `=緑角丸ボックスとし，タイトル1段・本文は既定で列優先の自動流し込み，YAML `layout:` (見出し名の行列指定) で見本のような不規則配置も後から明示できる二層構造にする．A1/A0 は `@page` ミリ指定と `--scale` 変数の文字サイズ倍率，向きは `data-orientation` 属性で Grid 定義ごと切替える．画像は `div.fig>img` (`p` を挟まない) を踏襲しつつ複数枚並び用の `::: figrow :::` を追加し，検算に「1ページ・用紙寸法・box はみ出し・実寸文字サイズ」を加える．
