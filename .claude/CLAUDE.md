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

- 2026-08-29 12:20 (このセッション，x280-home)
  **Mac/Linux 対応が GitHub Actions で完全に検証できた**．URL 修正後の CI は
  macOS・Ubuntu とも成功．**今回は「成功」の報告を鵜呑みにせず**，両 OS の
  Artifact から実際の PDF をダウンロードして中身を目視確認した．
  `poster_howto.pdf`・`golf_course.pdf` とも，箱の配置・表・画像・
  `layout:` の2行またがりまで意図どおり．**Ubuntu は CJK フォントが無いため
  「・」が □ (tofu) になる**が，これは SKILL.md に書いた既知の制限どおり (想定内)．
  これで build-poster-pdf の Mac/Linux 対応は完了とみなす．

- 2026-08-29 12:10 (x280-home)
  **CI が「成功」報告していたのに，実は Mac・Linux 両方とも中身が間違っていたことが発覚**．
  Artifact の PDF を実際に開いて見たら，2つの見本とも中身が Chrome の新規タブページ
  (Google 検索画面) になっていた (箱・ページ数などの検算は「形」しか見ておらず，
  この不具合を検出できていなかった)．原因は `[Uri]` クラスに URL 組み立てを任せていたこと．
  Windows のローカルで検証すると `([Uri]'/Users/...').AbsoluteUri` が**空文字列**になる
  ことを確認した (実機での挙動は未検証だが，結果と符合する)．**`[Uri]` に頼らず，
  パスが `/` で始まるか (Unix) `D:\...` の形か (Windows) で自前に分岐して組み立てる**
  方式に変更．Windows の回帰確認は済み (バイト数が既知の正しい値と一致)．
  **今回の教訓**: 検算は「ページ数・箱数・フォント名」のような形だけでなく，
  実際に生成物を開いて中身を見ないと，今回のような「形は合っているが中身が別物」の
  不具合は見逃す．

- それ以前は [notes/history.md](notes/history.md) を見る．

### 次にやること

**【決定 2026-08-29】ユーザースキルへの引き上げは todo から削除した**．
指示があれば改めて検討する (このセッションでは扱わない)．

**README.md の作成・Mac/Linux 対応とも完了した (2026-08-29)**．
GitHub Actions (`.github/workflows/test.yml`，macos-latest・ubuntu-latest) で
実際に2つの見本をビルドし，**Artifact の PDF を目視確認するところまで**やって
Mac/Linux で正しく組めることを確かめた．リポジトリは検証のため Public 化済み．

1. 見本 `poster.pdf` に近い体裁になり，**ユーザから指示があれば**，
   `~/.claude/skills/build-poster-pdf/` (3台共有のユーザースキル) へ引き上げる．
   それまではこの `acposter/.claude/skills/build-poster-pdf/` のままでよい．
2. CI の検算は「ページ数・箱数・フォント名」のような形しか見ておらず，
   今回のような「形は合っているが中身が別物」という不具合を見逃した実例がある．
   **余力があれば**，PDF からテキストを抽出して既知の文字列 (表題など) が
   含まれているかを CI で機械的に確かめる工程を足すと，今回のような取りこぼしを防げる
   (今回は手作業で目視確認したので即応した．次に不具合が起きたときも同じ手順でよい)．
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
