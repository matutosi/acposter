# 進捗の履歴

本体の「現在の状態」には日付時刻と3行以内の要約だけを残し，詳細はここへ移す．

## 2026-08-29

- 2026-08-29 12:20 (x280-home)
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

- 2026-08-29 11:50 (x280-home)
  **macOS ハングの真因を特定した**: `file://` URL の2重スラッシュ (下記) を直した
  あとも再現し，タイムアウト時に Chrome の stderr を出す診断を追加して分かった．
  **Chrome は PDF を正常に書き終えていた** (`NNN bytes written to file` が出ている)．
  それでも `chrome://newtab` を「incorrect profile type」で読めずプロセスだけ残り，
  `WaitForExit` が永遠に返らなかった．**プロセスの自然終了を待つのをやめ**，
  PDF ファイルの完成をポーリングで検知したら (既存の60秒ポーリング)，
  プロセスが残っていても強制終了する方式に変えた．Windows での回帰確認は済み．

- 2026-08-29 11:30 (x280-home)
  **CI (macOS) の失敗ログから，実バグを2件見つけて直した** (診断のためタイムアウトを
  120秒に設定していたので，「本当にハングしている」ことが確定できた)．
  (1) **`file://` URL の組み立て**: `'file:///' + パス` の手組みだと，Mac/Linux の
  絶対パスは元から `/` で始まるため `file:////...` と2重スラッシュになる →
  `([Uri]$html).AbsoluteUri` に置き換え．(2) **画像が埋め込まれない**:
  `--resource-path` 未指定で，md 内の相対パスが pandoc の起動時カレントディレクトリ
  基準で解決されていた (Ubuntu でも同じ警告が出ていた) → `--resource-path=$dir` を追加．
  この時点ではまだ (1) だけでは真因を解決できていなかった (次のエントリで判明)．

- 2026-08-29 11:10 (x280-home)
  **GitHub Actions の macOS ジョブが4時間以上ハングする不具合に気づいた**．
  `Start-Process -Wait` で Chrome を起動した直後から無反応になっていた．
  **恒久対策として**標準出力・標準エラーを必ずファイルへリダイレクトし (パイプが
  詰まってのハングを防ぐ)，`Process.WaitForExit(120000)` で120秒のタイムアウトを
  追加した (これ自体は原因ではなかったが，打ち切られたことで本当の原因調査が進んだ．
  詳細は直後のエントリ)．

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
