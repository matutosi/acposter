# acposter

**学術ポスター (A0/A1) を md から PDF にするツール**の要件定義・検証プロジェクト．
LaTeX を使わず，pandoc + ヘッドレス Chrome で組む．既存の R/ggplot2 製 `ggposter`
(`../ggposter/.claude/CLAUDE.md`) とは別系統 (置き換えではない)．

- 親の管理は [todo/.claude/CLAUDE.md](../../.claude/CLAUDE.md)．**進捗はここが正**．
- `poster.pdf` は **見本** (ggposter の出力例と同じもの)．体裁の目標として置いてある．

## 構成

| ファイル・ディレクトリ | 中身 |
|---|---|
| `poster.pdf` | 見本 PDF (A0 縦，緑角丸枠の2段組ポスター) |
| `requirements/` | 5エージェントによる独立要件定義 (`agent_A.md`〜`agent_E.md`) と，ユーザが確定した方針 (`decision.md`) |
| `.claude/skills/build-poster-pdf/` | ツール本体 (SKILL.md・ps1・css・lua)．**このプロジェクト専用スキル** |
| `test.md` / `test.pdf` | 動作確認に使った最小サンプル |

**ツール本体はこのプロジェクト専用スキルとして置く** (`acposter/.claude/skills/build-poster-pdf/`)．
**指示があるまでは** `~/.claude/skills/` (3台共有のユーザースキル) へは上げず，
acposter の git リポジトリだけで版管理する (2026-08-29 ユーザ指示)．

## ツールの使い方 (概要)

acposter ディレクトリで実行する．

```powershell
pwsh -File .claude/skills/build-poster-pdf/make_poster_pdf.ps1
```

型 (`type: "学術ポスター"`) を見て対象 md を選ぶ．引数・md の書き方の約束
(`layout:` による箱の配置指定，`{.full}` による部分全幅など) は
スキルの `SKILL.md` を見る．詳細はそちらが正．

## 要件定義の経緯 (2026-08-29)

「5エージェントが独立に考えて比較する」という進め方で要件定義した
(ユーザ指示)．5案とも読んで比較したい場合は `requirements/` を見る．

- **全案一致**: pandoc+Chrome+CSS (LaTeX 不使用)，既存2スキルと同じ3点構成，
  `# `見出し=緑角丸箱，画像は `div.fig>img`，`[メモ](img.png)` は画像記法の書き間違いとして救済．
- **分かれて決定した点**: 段組みは既定 CSS columns・`layout:` 指定時のみ CSS Grid の
  ハイブリッド，初版は MVP 優先 (ただし低コストな機能は含める)，段組み崩れの検出は
  自動化せず目視 + `-KeepHtml` 運用．詳細と理由は [requirements/decision.md](requirements/decision.md)．

## git 管理

**このディレクトリを独立した git リポジトリにし，GitHub (`matutosi/acposter`，Private)
をリモートにした** (2026-08-29 ユーザ指示)．`todo` 親リポジトリでは追跡しない
(gitlink になり二重管理になるため．親の運用ルールと同じ)．

## 進捗状況

### 現在の状態

- 2026-08-29 09:30 (このセッション，MATUTOSI_DP)
  **`build-poster-pdf` を `acposter` 専用のプロジェクトスキルへ移した**
  (`.claude/skills/build-poster-pdf/`．旧置き場所 `todo/.claude/user/skills/` は未コミットの
  ままだったので移動のみで済んだ)．**指示があるまでは**ユーザースキル (3台共有) へは上げない．

- 2026-08-29 09:20 (MATUTOSI_DP)
  **`build-poster-pdf` の動作確認をした (`test.md` → `test.pdf`)**．
  検算 (ページ数=1・箱数5/5・フォント埋め込み・用紙実寸 2384x3370pt) はすべて一致．
  2段組みの自動流し込み・`{.full}` の全幅指定・緑角丸枠・表題帯とも意図どおりに出た．
  **不具合を1件発見し修正済み**: `-Size` 引数とページ書き込み待ちループの `$size` 変数が
  PowerShell の大文字小文字非依存で衝突し，`ValidateSet` エラーで落ちていた (`$fileSize` に改名)．

- 2026-08-29 09:12 (MATUTOSI_DP)
  **`build-poster-pdf` スキルを新設し，このプロジェクトを git 管理・GitHub リモート化した**．
  5エージェントの要件定義 → ユーザ決定 (CSS Grid + layout のハイブリッド段組み，
  MVP優先，段組み崩れ検出は目視運用) を経て，SKILL.md・ps1・css・lua の4点を実装．

### 次にやること

1. `layout:` (CSS Grid モード) は今回のテストでは検証していない (既定の流し込みのみ確認済み)．
   見本 `poster.pdf` に近い非対称配置を試すときに検証する．
2. 見本 `poster.pdf` に近い体裁になり，**ユーザから指示があれば**，
   `~/.claude/skills/build-poster-pdf/` (3台共有のユーザースキル) へ引き上げる．
   それまではこの `acposter/.claude/skills/build-poster-pdf/` のままでよい．
