# acposter

**学術ポスター (A0/A1) を md から PDF にするツール**の要件定義・検証プロジェクト．
LaTeX を使わず，pandoc + ヘッドレス Chrome で組む．既存の R/ggplot2 製 `ggposter`
(`../ggposter/.claude/CLAUDE.md`) とは別系統 (置き換えではない)．

- 親の管理は [todo/.claude/CLAUDE.md](../../.claude/CLAUDE.md)．**進捗はここが正**．
- `poster.pdf` (ggposter の出力例と同じ見本) は**実在の研究者名を含むため，
  2026-08-30 にユーザ指示で `git filter-repo` により履歴ごとリポジトリから除いた**
  (`.gitignore` に追加済み．手元に置きたいときはこのファイル名のまま置いてよい)．

## 構成

| ファイル・ディレクトリ | 中身 |
|---|---|
| `requirements/` | 5エージェントによる独立要件定義 (`agent_A.md`〜`agent_E.md`) と，ユーザが確定した方針 (`decision.md`) |
| `.claude/skills/build-poster-pdf/` | ツール本体 (SKILL.md・ps1・css・lua)．**このプロジェクト専用スキル** |
| `examples/poster_howto.md` | **検証用サンプル1: ポスターのつくり方**．`ggposter` の howto サンプル
  (`inst/extdata/poster_sample_howto.yml`) を参考に，`build-poster-pdf` 自身の機能
  (箱・`layout:`・`{.full}`・`::: row`・画像救済) を1つずつ実演する．既定の段組み流し込み (`layout:` 無し) |
| `examples/poster_howto2.md` | **検証用サンプル3: 入力→出力の早見表**．`layout:` でページ全体を2段組にし，
  左列に入力例の箱・右列に出力例の箱を対にして並べる (ヘッダー・箇条書き・表・図の4対)．
  レイアウトの2箱だけは単独行 (全幅) で箱の中に入力・出力を上下に積む |
| `examples/golf_course.md` | **検証用サンプル2: ゴルフ場**．架空の研究データ (草地性種) を使った実例．
  `layout:` (CSS Grid) で非対称配置を再現する |
| `images/` | サンプルが使う仮の画像 (PIL で生成したプレースホルダー) |

**見本・検証用は上記のように限られた本数に揃える** (2026-08-29 ユーザ指示，2026-08-30 に3本目を追加)．
場当たり的な `test*.md` は作らない．新しい確認をしたいときは，既存のどれかに追記するか，
どうしても要るときだけ理由とともに増やす．
**`poster.pdf` (体裁の目標にした見本，実在の研究者名を含む) は2026-08-30 にリポジトリから
除いた** (下記「見本 PDF の扱い」)．

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

- 2026-08-30 (このセッション，x280-home) その6
  **設計方針を「現状維持 (pandoc + Chrome)」で確定し，`grid:` (座標指定) を追加した**．
  ユーザの「既存スキルを参考にしすぎでは．pandoc を使わない方法は」という問いから，
  md-to-pdf (Marked + Puppeteer) と**ダッシュボード3種** (flexdashboard・Streamlit 系・
  gridstack.js 系) を調べた．結論は**現状維持** (ユーザ確定)．理由: どの案も
  「レイアウトエンジンとして Chrome / WeasyPrint / 自前組版のどれかは必ず要る」ため
  **正味の依存は減らない**．WeasyPrint は CSS Grid の対応が不完全で `layout:` が壊れる恐れ，
  Puppeteer は専用 Chromium を自前で抱えるので依存はむしろ増える．
  一方 **gridstack.js の `{x,y,w,h}` 方式は取り入れる価値があると判断**し，
  `grid:` キーとして実装した (`layout:` の行列表記も従来どおり使える．`grid:` が優先)．
  重なり・右へのはみ出し・見出し名の不一致は pandoc がエラーで止める．
  **実装中に踏んだ罠**: `pandoc.utils.type()` は MetaMap に対して `'Map'` ではなく
  **`'table'` を返す**．`'Map'` で判定すると常に false になり，`grid:` が黙って無視されて
  既定の流し込みに落ちる (PDF はできてしまうので気づきにくい)．

- 2026-08-30 (x280-home) その5
  **`poster.pdf` (実在の研究者名を含む見本) を，過去のコミットも含めて履歴ごと削除した**
  (ユーザ指示．「無理なら最新版だけでも」との条件だったが，`git filter-repo`
  (`pip install git-filter-repo`) で**全18コミットから完全に除けた**)．
  手順: `git filter-repo --path poster.pdf --invert-paths --force` →
  (filter-repo が安全のため自動で外す) `origin` を再設定 → `.gitignore` に追加 →
  `git push --force-with-lease` で全面書き換え．**force push は今回の指示の範囲内**．
  作業ツリーの `poster.pdf` 自体も消える (履歴と一緒に消えるのが filter-repo の仕様)．

- それ以前は [notes/history.md](notes/history.md) を見る．

### 次にやること

**【決定 2026-08-30】全体の設計方針は pandoc + ヘッドレス Chrome のまま (ユーザ確定)**．
md-to-pdf・ダッシュボード3種を調べた上での結論なので，**以後は蒸し返さない**．
「pandoc をやめる」案 (Python の WeasyPrint 化・TypeScript の Puppeteer 化・自前組版) は
いずれも**正味の依存が減らない**か，CSS Grid の再現度が落ちるか，実装コストが不釣り合い．
経緯は「現在の状態」の 2026-08-30 その6 を見る．

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
