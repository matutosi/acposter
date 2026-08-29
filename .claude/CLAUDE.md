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

- 2026-08-29 11:10 (このセッション，x280-home)
  **GitHub Actions の macOS ジョブが4時間以上ハングする不具合を見つけて直した**．
  ログを見ると `Start-Process -Wait` で Chrome を起動した直後から無反応．
  Chrome の大量のログ出力 (macOS の Keystone アップデータ関連) をリダイレクトせず
  待っていたため，パイプが埋まってデッドロックしたと判断．
  **対策**: 標準出力・標準エラーを必ずファイルへリダイレクトし，
  `Process.WaitForExit(120000)` で120秒のタイムアウトを追加 (打ち切ったら明示的にエラー)．
  Windows での回帰確認は済み．CI (macOS) での再検証はこのあと行う．

- 2026-08-29 10:50 (x280-home)
  **要件の「できれば」3点を実際に動かして検証した** (ユーザ質問がきっかけ)．
  `-Orientation landscape` (横長)・`-Columns 3` (多段組)・`{.full}`/layout の
  単独行 (部分的な全幅化) の3つとも意図どおり動作．横長は既定の2段だと2ページに
  あふれたが，3段にすると1ページに収まった (用紙が横広になった分，列を増やす運用例)．

- 2026-08-29 10:30 (x280-home)
  **README.md を新設し，Mac/Linux 対応に着手した** (ユーザ指示で「引き上げ」の todo は削除)．
  ブラウザ探索を OS 別の既定パス + PATH 検索 (`google-chrome`・`chromium` 等) に変更，
  フォントに Hiragino Sans・Noto Sans CJK JP・IPAGothic のフォールバックを追加．
  Windows での回帰確認は済み (golf_course が引き続き1ページ・フォント埋め込み変化なし)．
  さらにリポジトリを Public 化し，GitHub Actions (macos-latest・ubuntu-latest) で
  実際にビルドして検証する仕組み (`.github/workflows/test.yml`) を追加した．

- それ以前は [notes/history.md](notes/history.md) を見る．

### 次にやること

**【決定 2026-08-29】ユーザースキルへの引き上げは todo から削除した**．
指示があれば改めて検討する (このセッションでは扱わない)．

1. **README.md は作成済み** (2026-08-29)．内容の過不足は今後気づいたときに直す．
2. **Mac/Linux 対応 (ブラウザ探索・フォント) は実装済み** (2026-08-29)．
   実機が手元に無いため，**GitHub Actions (macos-latest・ubuntu-latest) で検証する**方式にした
   (ユーザ指示．`.github/workflows/test.yml`)．そのため**リポジトリを Public にした**
   (2026-08-29．Private では Actions の無料枠が限られるため)．
   pandoc は `r-lib/actions/setup-pandoc` で入れ，2つの見本 (`examples/`) を実際にビルドして
   PDF が生成できるかを確認する．結果は Actions のログと Artifact (PDF) で見る．

1. README の作成 (2026-08-29 着手)．
2. Mac/Linux では現状そのままでは使えない件への対応 (2026-08-29 着手)．
   - **ブラウザ探索が Windows 専用**: `make_poster_pdf.ps1` は
     `$env:ProgramFiles\Google\Chrome\Application\chrome.exe` のような Windows のパスを
     決め打ちで探している．Mac/Linux では場所が違うので見つからない．
   - **フォントが Windows 標準の「UD デジタル教科書体 N」前提**: Mac/Linux には無く，
     代替フォントへフォールバックするが，見た目は想定どおりにならない．
   - PowerShell (`pwsh`) 自体は Mac/Linux にも入るので絶対的な障壁ではない．
   - 対策 (未着手・スコープ外): ブラウザ探索を `Get-Command`/PATH 検索に変える，
     OS ごとにフォント指定を切り替える．
   - **同じ設計 (pandoc + ヘッドレス Chrome + PowerShell ラッパー) の
     `build-abstract-pdf`・`build-slide-pdf` (ユーザースキル側) も同様に Windows 専用**．
     対応するなら3スキル共通の課題として扱う．
