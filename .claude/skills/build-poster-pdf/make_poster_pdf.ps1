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
  pwsh -File make_poster_pdf.ps1 -KeepHtml               # 中間 HTML を残して体裁を確認する
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
  [switch]$KeepHtml
)

$ErrorActionPreference = 'Stop'

$SUPPORTED_TYPES = @('学術ポスター', 'ポスター')

# A系列の縦向き実寸 (mm)．横長は幅高を入れ替える．
$SIZE_MM = @{ A0 = @{ w = 841; h = 1189 }; A1 = @{ w = 594; h = 841 } }
# 基準フォントサイズ (pt)．A1 は A0 の 1/√2 相当を丸めた値．
$FONT_PT = @{ A0 = 26; A1 = 18 }

function Get-FrontMatter([string]$path) {
  $lines = Get-Content -LiteralPath $path -Encoding UTF8
  if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
  $fm = [ordered]@{}
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { return $fm }
    if ($lines[$i] -match '^\s*#') { continue }
    if ($lines[$i] -match '^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$') {
      $fm[$matches[1]] = $matches[2].Trim().Trim('"', "'")
    }
  }
  return $fm
}

# --- 対象の md を決める -------------------------------------------------------
if (-not $Md) {
  $cands = @(Get-ChildItem -Path . -Filter '*.md' -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notmatch '^(README|CLAUDE)\.md$' } |
             Where-Object {
               $f = Get-FrontMatter $_.FullName
               $f -and $f.Contains('type') -and ($SUPPORTED_TYPES -contains $f['type'])
             })
  if ($cands.Count -eq 1) {
    $Md = $cands[0].FullName
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
  foreach ($p in @((Join-Path $dir $name), (Join-Path $dir "build\$name"), (Join-Path $PSScriptRoot $name))) {
    if (Test-Path $p) { return (Resolve-Path $p).Path }
  }
  throw "$name が見つからない．"
}
$Css = Resolve-Asset $Css 'poster.css'
$Lua = Resolve-Asset $Lua 'poster.lua'

# --- ヘッダー (YAML front matter) を読む -------------------------------------
$fm = Get-FrontMatter $Md
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

# --- 箱の数を数える (あとで検算の見込み値にする) -------------------------------
# コードブロックの中の見出し記号は数えない．
$inFence = $false
$boxCount = 0
foreach ($line in (Get-Content -LiteralPath $Md -Encoding UTF8)) {
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

$inc = Join-Path ([IO.Path]::GetTempPath()) ('poster-size-' + [Guid]::NewGuid().ToString('N') + '.html')
Set-Content -LiteralPath $inc -Encoding UTF8 -Value @"
<style>
@page { size: ${w}mm ${h}mm; }
html { font-size: $pt; }
:root { --content-columns: $Columns; }
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
  "--lua-filter=$Lua"
  "--css=$Css"
  "--include-in-header=$inc"
  "--output=$html"
)
if (-not ($fm -and $fm.Contains('title'))) { $pandocArgs += "--metadata=title=$stem" }
pandoc @pandocArgs
Remove-Item $inc -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { throw "pandoc が失敗した (exit $LASTEXITCODE)．layout の見出し名が本文と揃っているか確かめる．" }

Remove-Item $Pdf -Force -ErrorAction SilentlyContinue

# Chrome は起動元プロセスより先に終わることがあるので，出力の完成をポーリングで待つ．
# 一時プロファイルを使い，起動中の通常のブラウザと衝突させない．
$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('chrome-pdf-' + [Guid]::NewGuid().ToString('N'))
$url = 'file:///' + $html.Replace([char]92, '/')

Write-Host "chrome : $Pdf"
$browserArgs = @(
  '--headless=new'
  '--disable-gpu'
  '--no-sandbox'
  '--no-first-run'
  '--no-default-browser-check'
  '--disable-extensions'
  '--no-pdf-header-footer'
  '--virtual-time-budget=15000'
  "--user-data-dir=$profileDir"
  "--print-to-pdf=$Pdf"
  $url
)
# 標準出力・標準エラーは必ずファイルへリダイレクトする．リダイレクトしないと，
# Chrome が大量に吐くログ (macOS では Keystone アップデータのログなど) でパイプが
# 埋まり，-Wait が永遠に返らずハングすることがある (2026-08-29，GitHub Actions の
# macos-latest で実際に4時間以上ハングして発覚)．
# さらに WaitForExit にタイムアウトを設け，原因不明のハングでも必ず打ち切る．
$stdoutLog = Join-Path ([IO.Path]::GetTempPath()) ('chrome-stdout-' + [Guid]::NewGuid().ToString('N') + '.log')
$stderrLog = Join-Path ([IO.Path]::GetTempPath()) ('chrome-stderr-' + [Guid]::NewGuid().ToString('N') + '.log')
$proc = Start-Process -FilePath $browser -ArgumentList $browserArgs -NoNewWindow -PassThru `
  -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
if (-not $proc.WaitForExit(120000)) {
  try { $proc.Kill() } catch {}
  Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue
  throw 'Chrome の印刷が120秒以内に終わらなかった (ハングした可能性)．'
}
Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

# 書き込みが終わる (サイズが増えなくなる) まで最大 60 秒待つ
# ($Size は -Size 引数 (A0/A1) と大文字小文字を区別せず衝突するので $fileSize にする)
$deadline = (Get-Date).AddSeconds(60)
$fileSize = -1
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 300
  if (-not (Test-Path $Pdf)) { continue }
  $now = (Get-Item $Pdf).Length
  if ($now -gt 0 -and $now -eq $fileSize) { break }
  $fileSize = $now
}

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
if ($fonts -notcontains 'UDDigiKyokashoN') {
  Write-Warning 'UDDigiKyokashoN が埋め込まれていない．CSS のファミリ名を確かめる (末尾に -R / -B を付けない)．'
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
