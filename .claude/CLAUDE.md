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
| `examples/poster_howto.md` | **検証用サンプル1: ポスターのつくり方**．`ggposter` の howto サンプル
  (`inst/extdata/poster_sample_howto.yml`) を参考に，`build-poster-pdf` 自身の機能
  (箱・`layout:`・`{.full}`・`::: row`・画像救済) を1つずつ実演する．既定の段組み流し込み (`layout:` 無し) |
| `examples/golf_course.md` | **検証用サンプル2: ゴルフ場**．見本 `poster.pdf` (草地性種の実データ) に近い内容．
  `layout:` (CSS Grid) で非対称配置を再現する |
| `images/` | 上記2つのサンプルが使う仮の画像 (PIL で生成したプレースホルダー) |

**見本・検証用は上記の2種類だけに揃える** (2026-08-29 ユーザ指示)．
場当たり的な `test*.md` は作らない．新しい確認をしたいときは，この2つのどちらかに追記するか，
どうしても要るときだけ理由とともに増やす．

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

- 2026-08-30 (このセッション，x280-home)
  **CI に PDF の中身そのものを確かめる検算を追加した** (「次にやること」の余力項目に着手)．
  `pdftotext` (poppler-utils，無ければ apt/brew で入れる) で実際のテキストを抜き出し，
  見本ごとの既知の文字列 (`poster_howto` なら表題，`golf_course` なら本文の一節) が
  入っているかを機械的に確認する．2026-08-29 に見逃した「ページ数・箱数は合っているが
  中身が Chrome の新規タブページ」という不具合を，次からは自動で検出できるようになる．
  **CI (macOS・Ubuntu 両方) で実際に動作し，2見本とも `OK` を確認**．
  これで acposter の「次にやること」に残っているのは，ユーザースキルへの引き上げ
  (指示待ち) だけになった．

- 2026-08-29 12:20 (x280-home)
  **Mac/Linux 対応が GitHub Actions で完全に検証できた**．URL 修正後の CI は
  macOS・Ubuntu とも成功．**今回は「成功」の報告を鵜呑みにせず**，両 OS の
  Artifact から実際の PDF をダウンロードして中身を目視確認した．
  `poster_howto.pdf`・`golf_course.pdf` とも，箱の配置・表・画像・
  `layout:` の2行またがりまで意図どおり．**Ubuntu は CJK フォントが無いため
  「・」が □ (tofu) になる**が，これは SKILL.md に書いた既知の制限どおり (想定内)．
  これで build-poster-pdf の Mac/Linux 対応は完了とみなす．

- それ以前は [notes/history.md](notes/history.md) を見る．

### 次にやること

**【決定 2026-08-29】ユーザースキルへの引き上げは todo から削除した**．
指示があれば改めて検討する (このセッションでは扱わない)．

**README.md の作成・Mac/Linux 対応とも完了した (2026-08-29)**．
GitHub Actions (`.github/workflows/test.yml`，macos-latest・ubuntu-latest) で
実際に2つの見本をビルドし，**Artifact の PDF を目視確認するところまで**やって
Mac/Linux で正しく組めることを確かめた．リポジトリは検証のため Public 化済み．

1. **【判断待ち】** 見本 `poster.pdf` に近い体裁になり，**ユーザから指示があれば**，
   `~/.claude/skills/build-poster-pdf/` (3台共有のユーザースキル) へ引き上げる．
   それまではこの `acposter/.claude/skills/build-poster-pdf/` のままでよい．
2. 同じ設計 (pandoc + ヘッドレス Chrome + PowerShell ラッパー) の
   `build-abstract-pdf`・`build-slide-pdf` (ユーザースキル側) は，今回の
   Mac/Linux 対応 (ブラウザ探索・フォント・`file://` URL 組み立て) を反映していない．
   対応するかは指示があってから (3スキル共通の課題として扱う想定)．
