<#
.SYNOPSIS
  poster_common.ps1 (make_poster_pdf.ps1 の純関数) の単体テスト．

.DESCRIPTION
  ヘッダーの読み取り (Get-FrontMatter・Get-MetaValue)，引数とヘッダーからの
  設定の決定 (Resolve-Setting)，file:// URL の組み立て (ConvertTo-FileUrl) を，
  **pandoc も Chrome も呼ばずに**確かめる．数秒で終わり，3つの OS で同じに走る．
  run_lua_tests.ps1 と同じ書き方に揃えてある (Pester は使わない．Windows 同梱の
  Pester 3.4 は古く，Mac/Linux では別途入れることになるため)．

.EXAMPLE
  pwsh -File tests/run_ps1_tests.ps1
#>
[CmdletBinding()]
param([string]$Common = '')

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $Common) { $Common = Join-Path $root '.claude/skills/build-poster-pdf/poster_common.ps1' }
if (-not (Test-Path $Common)) { throw "poster_common.ps1 が無い: $Common" }
. $Common

$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('poster-ps1-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmpDir | Out-Null

$script:passed   = 0
$script:failures = @()

function Pass([string]$name) { $script:passed++; Write-Host ('  ok   ' + $name) }
function Fail([string]$name, [string]$why) {
  $script:failures += ($name + "`n        - " + $why)
  Write-Host ('  FAIL ' + $name) -ForegroundColor Red
}

# 値が見込みどおりか (食い違いが読めるよう，文字列にしてから比べる)．
function Test-Value([string]$Name, $Actual, $Expected) {
  $a = if ($null -eq $Actual)   { '<null>' } else { "$Actual" }
  $e = if ($null -eq $Expected) { '<null>' } else { "$Expected" }
  if ($a -eq $e) { Pass $Name } else { Fail $Name "期待: $e / 実際: $a" }
}

# 指定の文面を含むエラーで止まるか．
function Test-Throws([string]$Name, [scriptblock]$Body, [string]$ErrorMatch) {
  try {
    & $Body | Out-Null
    Fail $Name "エラーで止まるはずが通った (期待: $ErrorMatch)"
  } catch {
    if ("$($_.Exception.Message)" -match [regex]::Escape($ErrorMatch)) { Pass $Name }
    else { Fail $Name "エラーの文面が違う (期待: $ErrorMatch / 実際: $($_.Exception.Message))" }
  }
}

function Head([string]$s) { Write-Host ''; Write-Host $s -ForegroundColor Cyan }

# テスト用の md を書き出してパスを返す
$script:mdSeq = 0
function New-MdFile([string]$text) {
  $script:mdSeq++
  $p = Join-Path $tmpDir ('case{0}.md' -f $script:mdSeq)
  Set-Content -LiteralPath $p -Value $text -Encoding UTF8
  return $p
}

# ============================================================ Get-FrontMatter
Head 'Get-FrontMatter (ヘッダーを浅く読む)'

Test-Value 'ヘッダーが無ければ $null' `
  (Get-FrontMatter (New-MdFile "# 見出し`n`n本文`n")) $null

$fm = Get-FrontMatter (New-MdFile "---`ntitle: My Poster`ntype: 学術ポスター`n---`n`n# One`n")
Test-Value 'キーと値を読む'   $fm['title'] 'My Poster'
Test-Value '日本語の値も読む' $fm['type']  '学術ポスター'

$fm = Get-FrontMatter (New-MdFile "---`ntitle: `"Quoted`"`nauthor: 'Single'`n---`n`n本文`n")
Test-Value '二重引用符を外す' $fm['title']  'Quoted'
Test-Value '一重引用符を外す' $fm['author'] 'Single'

$fm = Get-FrontMatter (New-MdFile "---`n# これはコメント`ntitle: T`n---`n`n本文`n")
Test-Value 'コメント行 (#) は採らない' ($fm.Keys -join ',') 'title'

# `grid:` の下の `columns:` を拾うと，段数の指定と取り違える (2026-08-31 に踏んだ)
$fm = Get-FrontMatter (New-MdFile "---`ntitle: T`ngrid:`n  columns: 3`n---`n`n本文`n")
Test-Value '字下げのある行 (入れ子) は採らない' ($fm.Keys -join ',') 'title,grid'

$fm = Get-FrontMatter (New-MdFile "---`ntitle: T`n---`n`nbody: これは本文`n")
Test-Value '2つ目の --- で止まる (本文の key: value を拾わない)' ($fm.Keys -join ',') 'title'

# ============================================================ Get-MetaValue
Head 'Get-MetaValue (別名を順に見る)'

$fm = Get-FrontMatter (New-MdFile "---`nauthor: 正`nauthors: 別名`n---`n`n本文`n")
Test-Value '正のキーを優先する' (Get-MetaValue $fm @('author', 'authors')) '正'

$fm = Get-FrontMatter (New-MdFile "---`nauthors: 別名`n---`n`n本文`n")
Test-Value '正のキーが無ければ別名を採る' (Get-MetaValue $fm @('author', 'authors')) '別名'

$fm = Get-FrontMatter (New-MdFile "---`nauthor:`nauthors: 別名`n---`n`n本文`n")
Test-Value '空の値は無いものとして次を見る' (Get-MetaValue $fm @('author', 'authors')) '別名'

Test-Value 'どれも無ければ $null'             (Get-MetaValue $fm @('note'))     $null
Test-Value 'ヘッダーそのものが無ければ $null' (Get-MetaValue $null @('author')) $null

# ============================================================ ConvertTo-FileUrl
Head 'ConvertTo-FileUrl (file:// URL を自前で組み立てる)'

Test-Value 'Windows のパスは / に直して file:/// を付ける' `
  (ConvertTo-FileUrl 'D:\work\poster.tmp.html') 'file:///D:/work/poster.tmp.html'
Test-Value 'Unix の絶対パスはそのまま (スラッシュは3本)' `
  (ConvertTo-FileUrl '/home/me/poster.tmp.html') 'file:///home/me/poster.tmp.html'

# 逃がさないと Chrome が引数を割って "Multiple targets are not supported" で落ちる
Test-Value '空白は %20 に逃がす' `
  (ConvertTo-FileUrl 'D:\my poster\x.html') 'file:///D:/my%20poster/x.html'
Test-Value '# は %23 に逃がす (そこで URL が切れるため)' `
  (ConvertTo-FileUrl 'D:\a#b\x.html') 'file:///D:/a%23b/x.html'
Test-Value '? は %3F に逃がす' `
  (ConvertTo-FileUrl 'D:\a?b\x.html') 'file:///D:/a%3Fb/x.html'
# % を先に逃がさないと，逃がした先の % をもう一度逃がしてしまう
Test-Value '% は %25 に逃がす (二重に逃がさない)' `
  (ConvertTo-FileUrl 'D:\a%20b\x.html') 'file:///D:/a%2520b/x.html'

# ============================================================ Resolve-Setting
Head 'Resolve-Setting (引数 → ヘッダー → 既定値)'

# 用紙の検査と同じ形の $Check (小文字で書かれても大文字に正規化する)
$checkPaper = { param($v) $u = "$v".ToUpperInvariant(); if ($u -notin @('A0', 'A1')) { throw 'A0 か A1' }; $u }

# 呼び出し側の状態を毎回作り直す
function New-Ctx([hashtable]$header = @{}, [string[]]$bound = @()) {
  $f = [ordered]@{}
  foreach ($k in $header.Keys) { $f[$k] = $header[$k] }
  $b = @{}
  foreach ($k in $bound) { $b[$k] = $true }
  return @{
    Fm         = $f
    Bound      = $b
    FromHeader = [System.Collections.ArrayList]::new()
    Overridden = [System.Collections.ArrayList]::new()
  }
}

$c = New-Ctx
Test-Value 'どちらにも無ければ既定値のまま' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A0' -Check $checkPaper) 'A0'
Test-Value '  控えは空 (何も言わない)' ($c.FromHeader.Count + $c.Overridden.Count) 0

$c = New-Ctx @{ paper = 'A1' }
Test-Value 'ヘッダーだけならヘッダーを採る' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A0' -Check $checkPaper) 'A1'
Test-Value '  ヘッダーから採ったことを控える' ($c.FromHeader -join ',') 'paper=A1'

$c = New-Ctx @{} @('Size')
Test-Value '引数だけなら引数を採る' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A1' -Check $checkPaper) 'A1'

$c = New-Ctx @{ paper = 'A0' } @('Size')
Test-Value '両方あって値が違えば引数を採る' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A1' -Check $checkPaper) 'A1'
Test-Value '  捨てたほうを控える (黙って捨てない)' $c.Overridden.Count 1

$c = New-Ctx @{ paper = 'A1' } @('Size')
Test-Value '両方あっても同じ値なら何も言わない' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A1' -Check $checkPaper) 'A1'
Test-Value '  控えは空' ($c.FromHeader.Count + $c.Overridden.Count) 0

$c = New-Ctx @{ paper = 'a1' }
Test-Value 'ヘッダーの値も $Check で正規化する' `
  (Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A0' -Check $checkPaper) 'A1'

$c = New-Ctx @{ cols = '3' }
Test-Value 'ヘッダーの別名も見る' `
  (Resolve-Setting @c -Key 'columns' -Alias 'cols' -Param 'Columns' -Current 2 `
     -Check { param($v) $n = 0; if (-not [int]::TryParse("$v", [ref]$n) -or $n -lt 1) { throw '1 以上の整数' }; $n }) 3

$c = New-Ctx @{ paper = 'A2' }
Test-Throws 'ヘッダーが不正なら止まる' `
  { Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A0' -Check $checkPaper } 'ヘッダーの paper が不正'

# `-Size A0` を付けてあっても，ヘッダーの書き間違いは見逃さない (2026-08-31)
$c = New-Ctx @{ paper = 'A2' } @('Size')
Test-Throws '引数で上書きされる場合でもヘッダーを検査する' `
  { Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A0' -Check $checkPaper } 'ヘッダーの paper が不正'

# 2026-09-02 まで，引数側は検査されずに素通りしていた
$c = New-Ctx @{} @('Size')
Test-Throws '引数が不正なら止まる' `
  { Resolve-Setting @c -Key 'paper' -Param 'Size' -Current 'A2' -Check $checkPaper } '-Size が不正'

$c = New-Ctx @{} @('Font')
Test-Throws '書体に CSS を閉じる文字は通さない' `
  { Resolve-Setting @c -Key 'font' -Param 'Font' -Current 'serif, } .box { display: none' `
      -Check { param($v) if ("$v" -match '[{};\r\n]') { throw '{ } ; と改行は使えない' }; "$v" } } '-Font が不正'

$c = New-Ctx @{} @('FontSize')
Test-Throws '文字サイズは単位まで要る' `
  { Resolve-Setting @c -Key 'font-size' -Param 'FontSize' -Current '30' `
      -Check { param($v) if ("$v" -notmatch '^[0-9]+(\.[0-9]+)?(pt|px|mm|em|rem)$') { throw '例 30pt' }; "$v" } } '-FontSize が不正'

# ============================================================ 後始末と結果
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($failures.Count -eq 0) {
  Write-Host ('通過 {0} 件 / 失敗 0 件' -f $passed) -ForegroundColor Green
  exit 0
} else {
  Write-Host ('通過 {0} 件 / 失敗 {1} 件' -f $passed, $failures.Count) -ForegroundColor Red
  Write-Host ''
  foreach ($f in $failures) { Write-Host ('  ' + $f) -ForegroundColor Red }
  exit 1
}
