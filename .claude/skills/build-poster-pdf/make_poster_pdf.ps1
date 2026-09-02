<#
.SYNOPSIS
  学術ポスターの Markdown から，tex を経由せずに A0/A1 1枚の PDF を生成する．

.DESCRIPTION
  pandoc で Markdown を HTML に変換し，ヘッドレス Chrome で印刷して PDF にする．
  `# ` ごとに1つの緑角丸枠 (箱) になり，先頭にヘッダーから作った表題帯が付く．
  ヘッダーに `layout:` (見出し名の行列) があれば CSS Grid で配置し，
  無ければ既定の段組み流し込み (CSS columns) になる．体裁は poster.css，
  箱への切り分け・表題帯・layout の Grid 化は poster.lua で扱う．
  LaTeX は使わないので TeX Live が無い PC でも動く．

  CSS と Lua は「対象 md と同じディレクトリ」→「その下の build/」→「スキル同梱」の
  順に探す．プロジェクト側に置けば，そちらが優先される．

.EXAMPLE
  pwsh -File make_poster_pdf.ps1                        # md を自動で見つけて <基幹名>.pdf を作る
  pwsh -File make_poster_pdf.ps1 -Md poster.md
  pwsh -File make_poster_pdf.ps1 -Size A1                # A1 サイズで作る (既定は A0)
  pwsh -File make_poster_pdf.ps1 -Orientation landscape  # 横長で作る (既定は縦長)
  pwsh -File make_poster_pdf.ps1 -Columns 3              # layout 未指定のときの段数を3段にする
  pwsh -File make_poster_pdf.ps1 -FontSize 30pt          # 基準文字サイズを直接指定する
  pwsh -File make_poster_pdf.ps1 -Font "Yu Gothic"       # 書体を指定する (フォールバックは残る)
  pwsh -File make_poster_pdf.ps1 -Accent "#0b4f9e"       # 差し色 (枠・見出し帯・表題帯) を変える
  pwsh -File make_poster_pdf.ps1 -KeepHtml               # 中間 HTML を残して体裁を確認する

  用紙・向き・段数・文字サイズ・書体・差し色は md のヘッダーにも書ける (paper /
  orientation / columns / font-size / font / accent)．引数を書けばそちらが優先される．
  副題とロゴはヘッダーだけ (subtitle / logo)．
#>
[CmdletBinding()]
param(
  [string]$Md  = '',
  [string]$Pdf = '',
  [string]$Css = '',
  [string]$Lua = '',
  [ValidateSet('A0', 'A1')][string]$Size = 'A0',
  [ValidateSet('portrait', 'landscape')][string]$Orientation = 'portrait',
  [int]$Columns = 2,
  [string]$FontSize = '',
  [string]$Font = '',
  [string]$Accent = '',
  [switch]$KeepHtml
)

$ErrorActionPreference = 'Stop'

# 純関数 (ヘッダーの読み取り・設定の決定・file:// URL) は別ファイルに分けてある．
# tests/run_ps1_tests.ps1 が同じものを読み込んで単体で確かめる (2026-09-02)．
. (Join-Path $PSScriptRoot 'poster_common.ps1')

$SUPPORTED_TYPES = @('学術ポスター', 'ポスター')

# A系列の縦向き実寸 (mm)．横長は幅高を入れ替える．
$SIZE_MM = @{ A0 = @{ w = 841; h = 1189 }; A1 = @{ w = 594; h = 841 } }
# 基準フォントサイズ (pt)．A1 は A0 の 1/√2 相当を丸めた値．
$FONT_PT = @{ A0 = 32; A1 = 23 }

# --- 対象の md を決める -------------------------------------------------------
# 自動で見つけたときは，そのとき読んだヘッダーを控えておく (同じファイルを二度読まない)．
$fm = $null
if (-not $Md) {
  $found = @()
  foreach ($f in (Get-ChildItem -Path . -Filter '*.md' -File -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notmatch '^(README|CLAUDE)\.md$' })) {
    $h = Get-FrontMatter $f.FullName
    if ($h -and $h.Contains('type') -and ($SUPPORTED_TYPES -contains $h['type'])) {
      $found += ,@($f, $h)
    }
  }
  $cands = @($found | ForEach-Object { $_[0] })
  if ($cands.Count -eq 1) {
    $Md = $cands[0].FullName
    $fm = $found[0][1]
  } elseif ($cands.Count -eq 0) {
    throw ("type が {0} の md が見つからない．-Md で指定する．" -f ($SUPPORTED_TYPES -join ' / '))
  } else {
    $names = ($cands | ForEach-Object { $_.Name }) -join ', '
    throw "対象の md が複数ある ($names)．-Md でどれかを指定する．"
  }
}
if (-not (Test-Path $Md)) { throw "md が無い: $Md" }
$Md   = (Resolve-Path $Md).Path
$dir  = Split-Path $Md
$stem = [IO.Path]::GetFileNameWithoutExtension($Md)

# --- 出力先を決める (既定は <基幹名>.pdf) -------------------------------------
if (-not $Pdf) {
  $Pdf = Join-Path $dir ($stem + '.pdf')
} elseif (-not [IO.Path]::IsPathRooted($Pdf)) {
  $Pdf = Join-Path $dir $Pdf
}

# --- CSS / Lua を探す (md と同階層 → build/ → スキル同梱) ---------------------
function Resolve-Asset([string]$given, [string]$name) {
  if ($given) {
    if (-not (Test-Path $given)) { throw "指定されたファイルが無い: $given" }
    return (Resolve-Path $given).Path
  }
  # `build\` と直に書くと Mac/Linux では区切りにならず，build/ の探索が効かなかった
  # (2026-09-02 に気づいた)．OS ごとの区切りは Join-Path に任せる．
  foreach ($p in @((Join-Path $dir $name), (Join-Path (Join-Path $dir 'build') $name), (Join-Path $PSScriptRoot $name))) {
    if (Test-Path $p) { return (Resolve-Path $p).Path }
  }
  throw "$name が見つからない．"
}
$Css = Resolve-Asset $Css 'poster.css'
$Lua = Resolve-Asset $Lua 'poster.lua'

# --- ヘッダー (YAML front matter) を読む -------------------------------------
if ($null -eq $fm) { $fm = Get-FrontMatter $Md }
if ($null -eq $fm) {
  throw 'ヘッダー (--- で囲む YAML) が無い．title / author / institute / type を書く．'
} elseif (-not $fm.Contains('type')) {
  Write-Warning 'ヘッダーに type が無い．そのまま処理する．'
} elseif ($SUPPORTED_TYPES -notcontains $fm['type']) {
  throw ("type '{0}' はこのスキルの対象外．対象は {1}．" -f $fm['type'], ($SUPPORTED_TYPES -join ' / '))
} else {
  Write-Host ('type   : {0}' -f $fm['type'])
  if ($fm.Contains('date')) { Write-Host 'date   : 読み飛ばす (学術ポスターでは使わない)' }
  if (-not $fm.Contains('title')) { Write-Warning 'ヘッダーに title が無い．表題帯が出ない．' }
}

# --- 用紙・向き・段数・文字サイズをヘッダーからも受ける (引数が優先) -----------
# ggposter・qtposter はこれらを原稿のヘッダーに書く．acposter だけ「原稿の外」に
# 設定があると移し替えのたびに書き直しになるので，同じ名前でヘッダーにも書けるようにした
# (2026-08-31)．`size` は用紙 (ggposter) と文字サイズ (qtposter) の両方の意味で
# 使われているため，どちらの別名にもしない．用紙は `paper`，文字は `font-size` と書く．
# 引数とヘッダーからの決め方は poster_common.ps1 の Resolve-Setting に括ってある．
# 6つの設定はどれも「別名を見る → 検査する → 引数とヘッダーの食い違いを警告する」で
# 同じなので，違うのは $Check (その設定に許される書き方) だけになる．
$fromHeader = [System.Collections.ArrayList]::new()
$overridden = [System.Collections.ArrayList]::new()
# 6つの呼び出しに毎回同じものを渡さずに済むよう，共通の引数はまとめておく．
$ctx = @{
  Fm         = $fm
  Bound      = $PSBoundParameters   # 引数を「明示したか」を見るため
  FromHeader = $fromHeader
  Overridden = $overridden
}

# 差し色に使ってよい書き方 (CSS の宣言の途中へ差し込むので，閉じ記号を通さない)．
$COLOR_PATTERN = '^(#[0-9A-Fa-f]{3,8}|[A-Za-z]+|(rgb|rgba|hsl|hsla)\([0-9A-Za-z%.,\s/]+\))$'

$Size = Resolve-Setting @ctx -Key 'paper' -Param 'Size' -Current $Size -Check {
  param($v)
  $u = "$v".ToUpperInvariant()
  if (-not $SIZE_MM.Contains($u)) { throw 'A0 か A1' }
  $u
}

$Orientation = Resolve-Setting @ctx -Key 'orientation' -Param 'Orientation' -Current $Orientation -Check {
  param($v)
  $l = "$v".ToLowerInvariant()
  if ($l -notin @('portrait', 'landscape')) { throw 'portrait か landscape' }
  $l
}

$Columns = Resolve-Setting @ctx -Key 'columns' -Alias 'cols' -Param 'Columns' -Current $Columns -Check {
  param($v)
  $n = 0
  if (-not [int]::TryParse("$v", [ref]$n) -or $n -lt 1) { throw '1 以上の整数' }
  $n
}

$FontSize = Resolve-Setting @ctx -Key 'font-size' -Alias 'font_size' -Param 'FontSize' -Current $FontSize -Check {
  param($v)
  if ("$v" -notmatch '^[0-9]+(\.[0-9]+)?(pt|px|mm|em|rem)$') { throw '例 30pt．単位まで書く' }
  "$v"
}

$Font = Resolve-Setting @ctx -Key 'font' -Alias 'font-family', 'font_family' -Param 'Font' -Current $Font -Check {
  param($v)
  # 差し込む先は CSS の宣言の途中なので，宣言や規則を閉じられる文字は通さない．
  if ("$v" -match '[{};\r\n]') { throw '{ } ; と改行は使えない' }
  "$v"
}

$Accent = Resolve-Setting @ctx -Key 'accent' -Param 'Accent' -Current $Accent -Check {
  param($v)
  if ("$v" -notmatch $COLOR_PATTERN) { throw '例 #1a7a3c・navy・rgb(11 79 158)' }
  "$v"
}

if ($fromHeader.Count -gt 0) {
  Write-Host ('header : {0} (同名の引数を書けばそちらが優先)' -f ($fromHeader -join ', '))
}
if ($overridden.Count -gt 0) {
  Write-Warning ('ヘッダーと引数の両方にあり，値が違う．引数を採る: {0}' -f ($overridden -join ' / '))
}

# --- 箱の数を数える (あとで検算の見込み値にする) -------------------------------
# コードブロックの中の見出し記号は数えない．
# **ヘッダー (--- で囲む YAML) も飛ばす**．YAML のコメント (`# ...`) を箱として
# 数えてしまい，「箱の数が見込みと違う」と誤警告が出ていた (2026-09-02 に直した)．
$inFence  = $false
$inHeader = $false
$boxCount = 0
$lineNo   = 0
foreach ($line in (Get-Content -LiteralPath $Md -Encoding UTF8)) {
  $lineNo++
  if ($lineNo -eq 1 -and $line.Trim() -eq '---') { $inHeader = $true; continue }
  if ($inHeader) {
    if ($line.Trim() -eq '---') { $inHeader = $false }
    continue
  }
  if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
  if (-not $inFence -and $line -match '^#\s') { $boxCount++ }
}

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) { throw 'pandoc が見つからない．' }

# ヘッドレスで印刷できるブラウザを探す (Chrome を優先し，無ければ Edge/Chromium)．
# OS ごとに置き場所が違う (2026-08-29 Mac/Linux 対応)．$IsWindows 等は pwsh の自動変数．
$candidatePaths = if ($IsMacOS) {
  @(
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
  )
} elseif ($IsLinux) {
  @()   # Linux はディストロで場所がまちまちなので PATH 検索 (下) だけに頼る
} else {
  @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
  )
}
$browser = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) {
  # 決め打ちパスで見つからなければ PATH 上のコマンド名で探す (Linux はほぼこちら経由)
  $cmdNames = @('google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser', 'chrome', 'msedge')
  $cmd = Get-Command -Name $cmdNames -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { $browser = $cmd.Source }
}
if (-not $browser) { throw 'Chrome/Edge/Chromium が見つからない．' }

# --- 用紙サイズ・向き・段数・文字サイズを @page / html へ差し込む -------------
$mm = $SIZE_MM[$Size]
$w  = $mm.w; $h = $mm.h
if ($Orientation -eq 'landscape') { $tmp = $w; $w = $h; $h = $tmp }
$pt = if ($FontSize) { $FontSize } else { "$($FONT_PT[$Size])pt" }

# 書体は poster.css の並びの**先頭だけ**を差し替える (--user-font)．
# 総入れ替えにすると Mac/Linux 用のフォールバックまで消えてしまうため．
# 総称ファミリ (sans-serif など) と，自分で並びを書いた場合 (カンマを含む) は
# 引用符で囲まない．それ以外は空白を含む名前が多いので囲む．
$fontDecl = ''
if ($Font) {
  $generic = @('serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'system-ui')
  $value = if ($Font.Contains(',') -or ($generic -contains $Font.ToLowerInvariant())) {
    $Font
  } else {
    '"' + $Font.Trim('"', "'") + '"'
  }
  $fontDecl = "`n:root { --user-font: $value; }"
}

# 差し色は枠・見出し帯・表題帯をまとめて変える (poster.css の2つの変数を上書きする)．
# 値の検査は出どころによらず Resolve-Setting で済んでいる (ここで重ねて書かない)．
$accentDecl = ''
if ($Accent) {
  $accentDecl = "`n:root { --box-color: $Accent; --title-bg: $Accent; }"
}

$inc = Join-Path ([IO.Path]::GetTempPath()) ('poster-size-' + [Guid]::NewGuid().ToString('N') + '.html')
Set-Content -LiteralPath $inc -Encoding UTF8 -Value @"
<style>
@page { size: ${w}mm ${h}mm; }
html { font-size: $pt; }
:root { --content-columns: $Columns; }$fontDecl$accentDecl
</style>
"@

# 中間 HTML は md と同じ場所に置く (画像の相対パスを合わせるため)
$html = Join-Path $dir ($stem + '.tmp.html')

Write-Host "md     : $Md"
Write-Host "css    : $Css"
Write-Host ('用紙   : {0} {1} ({2}mm x {3}mm)' -f $Size, $Orientation, $w, $h)
Write-Host ('箱     : {0}個 (# の数)' -f $boxCount)

$pandocArgs = @(
  $Md
  '--from=markdown-implicit_figures'
  '--to=html5'
  '--standalone'
  '--embed-resources'
  "--resource-path=$dir"
  "--lua-filter=$Lua"
  "--css=$Css"
  "--include-in-header=$inc"
  "--output=$html"
)
if (-not ($fm -and $fm.Contains('title'))) { $pandocArgs += "--metadata=title=$stem" }
pandoc @pandocArgs
Remove-Item $inc -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { throw "pandoc が失敗した (exit $LASTEXITCODE)．layout の見出し名が本文と揃っているか確かめる．" }

# 既にある PDF は**必ず**消す．消せないまま先へ進むと，Chrome が書けないのに
# 古いファイルがそのまま残り，サイズが安定しているのでポーリングが「完成」と見なす．
# 中身は前回のままなのに成功と表示される (2026-09-02 に再現．ビューアで PDF を
# 開いたまま組み直すと起きる)．消せないならここで止める．
if (Test-Path $Pdf) {
  try { Remove-Item $Pdf -Force -ErrorAction Stop }
  catch { throw "既にある PDF を消せない: $Pdf (ビューア等で開いたままになっていないか確かめる)" }
}

# Chrome は起動元プロセスより先に終わることがあるので，出力の完成をポーリングで待つ．
# 一時プロファイルを使い，起動中の通常のブラウザと衝突させない．
$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('chrome-pdf-' + [Guid]::NewGuid().ToString('N'))
# file:// URL は自前で組み立てる (poster_common.ps1 の ConvertTo-FileUrl)．
$url = ConvertTo-FileUrl $html

Write-Host "chrome : $Pdf"
# **空白を含みうる値は自分で引用符を付ける**．Start-Process は配列の要素を
# 引用符で囲まずに1本のコマンドラインへ連結するので，付けないと引数が割れる
# (URL 側は上で %20 に逃がしてあるので囲まなくてよい)．
$browserArgs = @(
  '--headless=new'
  '--disable-gpu'
  '--no-sandbox'
  '--no-first-run'
  '--no-default-browser-check'
  '--disable-extensions'
  '--no-pdf-header-footer'
  '--virtual-time-budget=15000'
  ('--user-data-dir="{0}"' -f $profileDir)
  ('--print-to-pdf="{0}"' -f $Pdf)
  $url
)
# 標準出力・標準エラーは必ずファイルへリダイレクトする (リダイレクトしないと，
# Chrome が大量に吐くログでパイプが埋まりハングする環境がある)．
#
# **プロセスの自然終了は待たない**．Chrome は PDF を書き終えたあとも，
# `--user-data-dir` の一時プロファイルで `chrome://newtab` を開こうとして
# 「Requested load of chrome://newtab/ for incorrect profile type」というエラーを
# 出したまま**プロセスが終了しないことがある** (2026-08-29，GitHub Actions の
# macos-latest で実際に確認．ファイルは正常に書けているのにプロセスだけ残る)．
# そこで **PDF ファイルの完成をポーリングで検知し，見えたらプロセスを強制終了する**
# 方式にする (Windows/Linux では Chrome は自然終了するので，この方式でも変わらず動く)．
$stdoutLog = Join-Path ([IO.Path]::GetTempPath()) ('chrome-stdout-' + [Guid]::NewGuid().ToString('N') + '.log')
$stderrLog = Join-Path ([IO.Path]::GetTempPath()) ('chrome-stderr-' + [Guid]::NewGuid().ToString('N') + '.log')
$proc = Start-Process -FilePath $browser -ArgumentList $browserArgs -NoNewWindow -PassThru `
  -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

# 書き込みが終わる (サイズが増えなくなる) まで最大 60 秒待つ．
# ($Size は -Size 引数 (A0/A1) と大文字小文字を区別せず衝突するので $fileSize にする)
$deadline = (Get-Date).AddSeconds(60)
$fileSize = -1
$stable = $false
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 300
  if (-not (Test-Path $Pdf)) { continue }
  $now = (Get-Item $Pdf).Length
  if ($now -gt 0 -and $now -eq $fileSize) { $stable = $true; break }
  $fileSize = $now
}

# プロセスが自分で終わっていなければ，ここで強制終了する (上のポーリングで
# ファイルの完成は確認済みなので，プロセスが残っていても内容には影響しない)．
if (-not $proc.HasExited) {
  try { $proc.Kill() } catch {}
}
if (-not $stable) {
  # ファイルが安定しないまま打ち切った場合だけ，原因調査用にログを出す．
  Write-Host '--- chrome stdout (timeout) ---'
  Get-Content -LiteralPath $stdoutLog -ErrorAction SilentlyContinue | Write-Host
  Write-Host '--- chrome stderr (timeout) ---'
  Get-Content -LiteralPath $stderrLog -ErrorAction SilentlyContinue | Write-Host
}
Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

if (Test-Path $profileDir) { Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue }

if (-not (Test-Path $Pdf)) {
  if (-not $KeepHtml) { Remove-Item $html -Force -ErrorAction SilentlyContinue }
  throw 'PDF が生成されなかった．'
}

# --- 検算: 中間 HTML の箱の数 (削除する前に数える) -----------------------------
$htmlText = Get-Content -LiteralPath $html -Raw -Encoding UTF8
$boxInHtml = [regex]::Matches($htmlText, 'class="box(?:\s|")').Count
if (-not $KeepHtml) { Remove-Item $html -Force -ErrorAction SilentlyContinue }

# --- 検算: ページ数・用紙実寸・埋め込みフォント -------------------------------
$bytes = [IO.File]::ReadAllBytes($Pdf)
$latin = [Text.Encoding]::GetEncoding('ISO-8859-1').GetString($bytes)
$fonts = [regex]::Matches($latin, '/BaseFont\s*/([A-Za-z0-9+#,._-]+)') |
         ForEach-Object { $_.Groups[1].Value -replace '^[A-Z]{6}\+', '' } |
         Sort-Object -Unique
$pages = [regex]::Matches($latin, '/Type\s*/Page[^s]').Count

Write-Host ('完成: {0} ({1:N0} bytes)' -f $Pdf, (Get-Item $Pdf).Length)
Write-Host ('ページ数: {0} (ポスターは常に1のはず)' -f $pages)
if ($pages -ne 1) {
  Write-Warning 'ページ数が1でない．どこかの箱・画像・表が用紙からあふれている．-KeepHtml で中間 HTML を確かめる．'
}
Write-Host ('箱の数: HTML {0}個 / 見込み {1}個' -f $boxInHtml, $boxCount)
if ($boxInHtml -ne $boxCount) {
  Write-Warning ('箱の数が見込みと違う ({0} と {1})．layout との突き合わせでエラーになっていないか確かめる．' -f $boxInHtml, $boxCount)
}

Write-Host ('埋め込みフォント: {0}' -f ($fonts -join ', '))
if ($Font) {
  # 書体を指定したときは既定の UD デジタル教科書体でなくて当たり前なので，
  # 「指定したものが実際に埋め込まれたか」を見る (空白と引用符を落として突き合わせる)．
  $want = ($Font -split ',')[0].Trim().Trim('"', "'") -replace '\s', ''
  if (-not ($fonts | Where-Object { $_ -replace '[\s,-]', '' -like "$want*" })) {
    Write-Warning ("指定した書体 '{0}' が埋め込まれていない．名前が合っているか，その PC に入っているかを確かめる．" -f $Font)
  }
} elseif ($IsWindows -and $fonts -notcontains 'UDDigiKyokashoN') {
  Write-Warning 'UDDigiKyokashoN が埋め込まれていない．CSS のファミリ名を確かめる (末尾に -R / -B を付けない)．'
} elseif ($fonts -notcontains 'UDDigiKyokashoN') {
  # UD デジタル教科書体は Windows 10/11 にしか入っていない．
  # Mac/Linux では CSS のフォールバックで組まれるのが正しいので，警告にはしない．
  Write-Host 'note   : UD デジタル教科書体が無いので，CSS のフォールバックで組んだ (体裁は Windows と完全には一致しない)．'
}

$mb = [regex]::Match($latin, '/MediaBox\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]')
if ($mb.Success) {
  $actualW = [double]$mb.Groups[3].Value - [double]$mb.Groups[1].Value
  $actualH = [double]$mb.Groups[4].Value - [double]$mb.Groups[2].Value
  $expectW = $w * 72.0 / 25.4
  $expectH = $h * 72.0 / 25.4
  Write-Host ('用紙実寸: {0:N0} x {1:N0} pt (見込み {2:N0} x {3:N0} pt)' -f $actualW, $actualH, $expectW, $expectH)
  if ([Math]::Abs($actualW - $expectW) -gt 3 -or [Math]::Abs($actualH - $expectH) -gt 3) {
    Write-Warning ('用紙実寸が指定した {0} {1} と合っていない．Chrome が既定の用紙サイズに落ちている可能性がある．' -f $Size, $Orientation)
  }
}
