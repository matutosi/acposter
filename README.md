# acposter

md 原稿から学術ポスター (A0/A1・1枚) の PDF を作るツール，`build-poster-pdf` の
開発・検証プロジェクト．**LaTeX を使わず**，pandoc + ヘッドレス Chrome で組む．

見本の体裁 ([poster.pdf](poster.pdf)) は，既存の R/ggplot2 製ポスターツール
[ggposter](https://github.com/matutosi/ggposter) の出力例と同じもの．
ggposter とは別系統のツールで，どちらを使うかは案件ごとに選べる．

## つくれるもの

- 用紙: A0 または A1 (縦・横)
- `# 見出し` ごとに1つの緑角丸枠 (箱)
- 既定は2段組みの新聞調の流し込み，ヘッダーに `layout:` を書けば
  CSS Grid で箱の配置 (非対称な行またぎ・全幅なども) を明示できる
- 画像1枚・複数枚の横並び (`::: row`)，表，箇条書き

## 使い方

```powershell
pwsh -File .claude/skills/build-poster-pdf/make_poster_pdf.ps1 -Md <ファイル>.md
```

引数・md の書き方の約束は
[`.claude/skills/build-poster-pdf/SKILL.md`](.claude/skills/build-poster-pdf/SKILL.md) が正．

## 見本

| ファイル | 内容 |
|---|---|
| [`examples/poster_howto.md`](examples/poster_howto.md) | ツール自身の機能 (箱・`layout:`・`{.full}`・`::: row`・画像救済) を1つずつ実演する．[ggposter の howto サンプル](https://github.com/matutosi/ggposter/blob/main/inst/extdata/poster_sample_howto.yml) を参考にした |
| [`examples/golf_course.md`](examples/golf_course.md) | 見本 `poster.pdf` (草地性種の実データ) に近い内容．`layout:` で非対称配置を再現する |

いずれも `pwsh -File .claude/skills/build-poster-pdf/make_poster_pdf.ps1 -Md examples/<ファイル>` で
PDF を作れる (`golf_course.md` は文字がやや大きいので `-FontSize 22pt` を付ける)．

## 開発の経緯

要件定義は「5エージェントが独立に考えて比較する」という進め方で行った．
各案の全文は [`requirements/agent_A.md`](requirements/agent_A.md) 〜
[`requirements/agent_E.md`](requirements/agent_E.md)，決定した方針は
[`requirements/decision.md`](requirements/decision.md) にある．

## 現状 (2026-08-29)

- **Windows 専用**．pandoc + Chrome/Edge (ヘッドレス印刷) + PowerShell (`pwsh`) で動く．
  Mac/Linux 対応は検討中 ([`.claude/CLAUDE.md`](.claude/CLAUDE.md) の「次にやること」を見る)．
- **`build-poster-pdf` はこのリポジトリだけで版管理している**プロジェクト専用スキル．
  指示があるまでは，3台共有のユーザースキル (`~/.claude/skills/`) へは上げない．
- 開発の詳しい進捗は [`.claude/CLAUDE.md`](.claude/CLAUDE.md) を見る．
