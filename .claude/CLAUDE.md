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
  左列に入力例の箱・右列に出力例の箱を対にして並べる (ヘッダー・箇条書き・表・図・
  レイアウト2段/1段の6対．**全項目が左=入力・右=出力で揃っている**) |
| `examples/poster_howto3.md` | **検証用サンプル4: 非対称な配置**．`grid:` の座標指定で3列にし，
  右に縦3行またがりの箱・下に全幅の箱を置く．`layout:` (行列) と `grid:` (座標) の書き分けを解説する |
| `examples/golf_course.md` | **検証用サンプル2: ゴルフ場**．架空の研究データ (草地性種) を使った実例．
  `layout:` (CSS Grid) で非対称配置を再現する |
| `images/` | サンプルが使う仮の画像 (PIL で生成したプレースホルダー) |
| `tests/run_lua_tests.ps1` | `poster.lua` の単体テスト (42件)．`pwsh -File tests/run_lua_tests.ps1`．CI でも回す |
| `tests/run_ps1_tests.ps1` | `poster_common.ps1` (ps1 の純関数) の単体テスト (35件)．pandoc も Chrome も要らない．CI でも回す |

**見本・検証用は上記のように限られた本数に揃える** (2026-08-29 ユーザ指示，2026-08-30 に3・4本目を追加)．
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

- 2026-09-02 09:05 (このセッション，MATUTOSI_DP) その18
  **積み残しのリファクタリング3件とテスト1件を片づけた** (点検の残り)．
  - **lua**: `is_map`・`to_num` を `Pandoc()` の中から **top-level へ出した**
    (呼ばれるたびに定義し直さなくなり，外からも触れる)．`by_name` の組み立てが
    `grid:` 節と `layout:` 節で重複していたのを **`index_by_name()` に括った**．
  - **ps1**: 純関数を **`poster_common.ps1` に切り出した** (`Get-FrontMatter`・
    `Get-MetaValue`・`Resolve-Setting`・`ConvertTo-FileUrl`)．`Resolve-Setting` は
    `$fm`・`$PSBoundParameters` をスクリプトの変数から直に読んでいたので，
    **引数で受け取る形にして `$ctx` の splat で渡す** (呼び出し側の見た目はほぼ同じ)．
  - **`-Md` を省いたとき，同じファイルのヘッダーを2回読んでいた**のをやめた
    (探索のときに読んだものを控えて使う)．
  - **`tests/run_ps1_tests.ps1` を新設 (35件)**．**Pester は使わない** —
    この PC に入っているのは Windows 同梱の 3.4.0 で古く，Mac/Linux では別途
    入れることになるため，`run_lua_tests.ps1` と同じ自前ハーネスに揃えた．
    pandoc も Chrome も要らない．**CI にも入れた** (lua テストの直後)．
  - **検証**: テスト 42+35 件，見本4本が**中間 HTML までバイト一致**
    (この PC の pandoc 3.8.2.1 で HEAD 版と新版を突き合わせた)，
    壊れた md と不正な引数4通りが非0で止まること，ヘッダーと引数の優先関係
    (ヘッダーのみ・食い違いの警告・同じ値なら無言)，`-Md` 省略時の自動選択
    (README 除外・型で選ぶ・複数ならエラー) が変わらないことを確かめた．

- 2026-09-02 08:40 (x280-home) その17
  **ps1 をリファクタリングし，引数側の検査漏れと小物を片づけた** (点検の残りの C・D)．
  - **`Resolve-Setting` に括った**．paper/orientation/columns/font-size/font/accent の
    6ブロック (ほぼ同型の8行) が1つの呼び出しになり，**検査を値の出どころで
    分けなくなった**．これで**バグ4が構造的に消えた**: それまで
    `-Font 'serif, } .box { display: none'` が CSS に素通しされて**箱が全部消え**，
    `-FontSize 30` (単位なし)・`-Columns 0` は無効な CSS になって黙って既定値に
    落ちていた (ヘッダーに同じことを書けば止まるのに，引数だと通っていた)．
    accent の色の正規表現の2重定義も消えた (`$COLOR_PATTERN` 1つ)．
  - **バグ8**: 箱の数の検算がヘッダーの YAML コメント (`# ...`) を数えていた．
    front matter を飛ばして数える．
  - **`Resolve-Asset` の `"build\$name"`** はバックスラッシュ直書きで，Mac/Linux で
    `build/` の探索が効いていなかった．`Join-Path` を重ねる形に直した．
  - **文書と実装の食い違い2件**を直した (SKILL.md の `--fig-max-h` は 30vh ではなく
    **13vh**，基準文字サイズは A0=26pt/A1=18pt ではなく **A0=32pt/A1=23pt**)．
  - **CI に windows-latest を足した** (主戦場なのに無く，`$IsWindows` の分岐が
    未検証だった)．`pdftotext` の検査だけは apt も brew も無いので Mac/Linux 限り．
    **異常系の手順も足した** — 壊れた md で非0終了し PDF ができないことを見る．
  - **検証**: 4つの不正な引数がすべてエラーで止まること，ヘッダーの優先関係
    (ヘッダーのみ・食い違いの警告・同じ値なら無言・引数があってもヘッダーを検査) が
    変わらないこと，テスト42件，見本4本が**中間 HTML までバイト一致**で組めることを確認．

- 2026-09-02 07:55 (x280-home) その16
  **`poster.lua` に検査3件を足し，単体テストを新設した** (点検の残りの B)．
  - **バグ5**: `x: 0.9` が `math.floor` で 0 に，`x: なにか` が既定値の 0 に
    黙って落ちていた．`to_num()` に欄の名前を渡し，**整数でなければ止める**
    (`grid.columns` も同じ)．**バグ6**: `grid.boxes` に同じ名前を2回書くと
    後のほうだけが残り，先の座標が消えていた (別のマスなら重なり検査もすり抜ける)．
    **バグ7**: `layout:` の重複が長方形でないと `grid-template-areas` が不正になり，
    **ブラウザが宣言ごと捨てて箱が勝手な位置へ散っていた**．行×列の実際のマスから
    各名前の外接矩形を取り，面積が一致しなければ止める．
  - **`tests/run_lua_tests.ps1` を新設 (42件)**．小さな md を pandoc に通し，
    HTML とエラー・警告の文面を確かめる．**Chrome も画像も要らない**ので数秒で終わり，
    3つの OS で同じに走る．表題帯・別名キー・箱の切り分け・`{.full}`・`div.fig`・
    リンク救済・改行の詰め方・`layout`/`grid` の変換・**エラー14種**を見る．
    **CI (`test.yml`) の先頭に入れた** (見本のビルドより前)．
  - **検査を外すと該当の3件だけが落ちる**ことを確かめた (回帰を捕まえる)．
  - **テストが実装の食い違いを1つ捕まえた**: 表題帯は `<div>` ではなく
    **`<section class="title-band">`** で出る (pandoc が見出しを含む Div を
    section にするため)．テスト側を実際の出力に合わせた．

- それ以前は [notes/history.md](notes/history.md) を見る．

### 次にやること

**【点検 2026-09-02】点検で挙がったバグ8件・文書の食い違い2件・
リファクタリング5件・テストの穴4件は，すべて片づいた** (上の その15〜18)．
**この点検からの積み残しは無い**．

いまのテストは lua 42件・ps1 35件で，どちらも pandoc/Chrome を要らない範囲を見る．
**Chrome まで通す確認は CI (3つの OS で見本4本) に任せている**．

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

**【完了 2026-08-31】`build-abstract-pdf`・`build-slide-pdf` へ Mac/Linux 対応を反映した**
(ユーザ指示)．ブラウザ探索・`file://` URL の組み立て・CSS のフォールバックの3点．
あわせて，このスキルの埋め込みフォントの検算も Mac/Linux で誤警告しないように直した
(UD デジタル教科書体が無い環境では警告ではなく note を出す)．

**【決定 2026-08-31】ユーザースキルへの引き上げは，次にやることから外した** (ユーザ指示)．
やるときはユーザから指示が出る．それまではこの `acposter/.claude/skills/build-poster-pdf/` のまま．
