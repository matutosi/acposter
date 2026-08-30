# acposter

md 原稿から学術ポスター (A0/A1・1枚) の PDF を作るツール，`build-poster-pdf` の
開発・検証プロジェクト．**LaTeX を使わず**，pandoc + ヘッドレス Chrome で組む．

体裁の目標にした見本 (研究者の実名を含むため非公開) は，既存の R/ggplot2 製ポスターツール
[ggposter](https://github.com/matutosi/ggposter) の出力例と同じもの．
ggposter とは別系統のツールで，どちらを使うかは案件ごとに選べる．

## つくれるもの

- 用紙: A0 または A1 (縦・横)
- `# 見出し` ごとに1つの緑角丸枠 (箱)
- 既定は2段組みの新聞調の流し込み。ヘッダーに `layout:` (見た目どおりの行列) か
  `grid:` (各箱の `x`/`y`/`w`/`h` 座標) を書けば，CSS Grid で箱の配置
  (非対称な行またぎ・全幅なども) を明示できる
- 画像1枚・複数枚の横並び (`::: row`)，表，箇条書き

## 使い方

```powershell
pwsh -File .claude/skills/build-poster-pdf/make_poster_pdf.ps1 -Md <ファイル>.md
```

用紙・向き・段数・文字サイズは**引数でも md のヘッダーでも書ける**
(`paper`・`orientation`・`columns`・`font-size`)．
**両方に書いたときは引数が勝ち，値が食い違えば警告が出る** (同じ値なら黙って通る)．

引数・md の書き方の約束は
[`.claude/skills/build-poster-pdf/SKILL.md`](.claude/skills/build-poster-pdf/SKILL.md) が正．

## ggposter・qtposter との行き来

同じ種類のポスターを作るツールが3系統ある (acposter・[ggposter](https://github.com/matutosi/ggposter)・qtposter)．
**本文の書き方は統一できない**が (構造化データと散文という根の違い)，
**ヘッダーのキー名は3つとも別名で受ける** (`author`/`authors`/`poster-authors` など)．
配置を移したいときは，acposter と ggposter で**完全に同じ書式**の `grid:` を使う
(`layout:` は同名で構造が違うので移し替えには使えない)．
3つの比較は `todo/.claude/notes/poster_tools.md`，細かい対応表は SKILL.md の
「姉妹ツールとの行き来」節にある．

## 見本

| ファイル | 内容 |
|---|---|
| [`examples/poster_howto.md`](examples/poster_howto.md) | ツール自身の機能 (箱・`layout:`・`{.full}`・`::: row`・画像救済) を1つずつ実演する．[ggposter の howto サンプル](https://github.com/matutosi/ggposter/blob/main/inst/extdata/poster_sample_howto.yml) を参考にした |
| [`examples/poster_howto2.md`](examples/poster_howto2.md) | 「入力 (md) → 出力」の早見表。`layout:` でページ全体を2段組にし，左列に入力例の箱・右列に出力例の箱を対にして並べる (ヘッダー・箇条書き・表・図・レイアウト2段/1段の6対) |
| [`examples/poster_howto3.md`](examples/poster_howto3.md) | **非対称な配置**の例。`grid:` の座標指定で3列にし，右に縦3行またがりの箱，下に全幅の箱を置く。`layout:` (行列) と `grid:` (座標) の書き分けを解説する |
| [`examples/golf_course.md`](examples/golf_course.md) | 架空の研究データ (草地性種) を使った，見本に近い実例。`layout:` で非対称配置を再現する |

いずれも `pwsh -File .claude/skills/build-poster-pdf/make_poster_pdf.ps1 -Md examples/<ファイル>` で
PDF を作れる (文字を小さくする必要のある見本は，ヘッダーに `font-size: 26pt` と書いてある)．

## 開発の経緯

要件定義は「5エージェントが独立に考えて比較する」という進め方で行った．
各案の全文は [`requirements/agent_A.md`](requirements/agent_A.md) 〜
[`requirements/agent_E.md`](requirements/agent_E.md)，決定した方針は
[`requirements/decision.md`](requirements/decision.md) にある．

## 現状 (2026-08-30)

- **Windows・Mac・Linux で動く**。pandoc + Chrome/Edge/Chromium (ヘッドレス印刷) +
  PowerShell (`pwsh`) で動く。Mac/Linux は GitHub Actions
  (`.github/workflows/test.yml`) で実際にビルドし，PDF の中身まで確認している。
- **`build-poster-pdf` はこのリポジトリだけで版管理している**プロジェクト専用スキル．
  指示があるまでは，3台共有のユーザースキル (`~/.claude/skills/`) へは上げない．
- 開発の詳しい進捗は [`.claude/CLAUDE.md`](.claude/CLAUDE.md) を見る．
