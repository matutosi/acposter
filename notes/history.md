# 進捗の履歴

本体の「現在の状態」には日付時刻と3行以内の要約だけを残し，詳細はここへ移す．

## 2026-08-29

- 2026-08-29 10:10 (x280-home)
  **見本・検証用ファイルを2種類に整理した** (ユーザ指示)．`test*.md` は削除し，
  `examples/poster_howto.md` (`ggposter` の howto サンプルを参考にした，
  ツール自身の機能デモ．layout 無しの既定の流し込み) と `examples/golf_course.md`
  (見本 poster.pdf に近い実データ，`layout:` で非対称配置) の2本に統一．
  さらに `::: row` 内の画像が div.fig に包まれていなかった不具合を lua 側で修正
  (Div の中まで再帰するようにした)．poster_howto は1ページに収まり，golf_course は
  `-FontSize 22pt` で1ページに収まることを確認 (既定 26pt だと2ページにあふれる実例)．

- 2026-08-29 09:55 (x280-home)
  **見本 `poster.pdf` に近いフルコンテンツで通しテストした (`test_full.md`)**．
  `layout:` の2行またがり配置・画像記法の救済 (`[..](img.jpg)`)・`::: row` 横並びは
  すべて意図どおり．一方，プレースホルダー画像が大きすぎて箱が伸びきり2ページ目にあふれた．
  **原因を特定し `poster.css` に対策を追加**: 画像の高さを既定で画面高さの16%
  (`--fig-max-h: 16vh`) に制限．さらに `::: row` 内の画像だけ縮まない不具合も見つけ，
  原因 (`width:100%` の明示指定が `max-height` との縦横同時収まり計算を妨げていた) を
  特定して直した (SKILL.md にも上書き方法を追記)．

- 2026-08-29 09:40 (x280-home)
  **`layout:` (CSS Grid モード) を検証した (`test_layout.md` → `test_layout.pdf`)**．
  `[OBJECTIVES, CONCLUSIONS]` / `[BACKGROUNDS, RESULTS]` / `[METHODS, RESULTS]` / `[SUMMARY]`
  の指定どおり，RESULTS が2行にまたがる縦長の箱に，SUMMARY が全幅の箱になった．検算も一致．

- 2026-08-29 09:30 (x280-home)
  **`build-poster-pdf` を `acposter` 専用のプロジェクトスキルへ移した**
  (`.claude/skills/build-poster-pdf/`．旧置き場所 `todo/.claude/user/skills/` は未コミットの
  ままだったので移動のみで済んだ)．**指示があるまでは**ユーザースキル (3台共有) へは上げない．

- 2026-08-29 09:20 (x280-home)
  **`build-poster-pdf` の動作確認をした (`test.md` → `test.pdf`)**．
  検算 (ページ数=1・箱数5/5・フォント埋め込み・用紙実寸 2384x3370pt) はすべて一致．
  2段組みの自動流し込み・`{.full}` の全幅指定・緑角丸枠・表題帯とも意図どおりに出た．
  **不具合を1件発見し修正済み**: `-Size` 引数とページ書き込み待ちループの `$size` 変数が
  PowerShell の大文字小文字非依存で衝突し，`ValidateSet` エラーで落ちていた (`$fileSize` に改名)．

- 2026-08-29 09:12 (x280-home)
  **`build-poster-pdf` スキルを新設し，このプロジェクトを git 管理・GitHub リモート化した**．
  5エージェントの要件定義 → ユーザ決定 (CSS Grid + layout のハイブリッド段組み，
  MVP優先，段組み崩れ検出は目視運用) を経て，SKILL.md・ps1・css・lua の4点を実装．
