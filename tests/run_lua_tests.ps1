<#
.SYNOPSIS
  poster.lua (pandoc Lua フィルタ) の単体テスト．

.DESCRIPTION
  小さな md を pandoc に通し，出てきた HTML と，エラー・警告の文面を確かめる．
  **Chrome も画像も要らない**ので速く，Windows / Mac / Linux のどれでも同じに走る．
  ポスターが「組めるか」ではなく「**書き間違いを黙って通さないか**」を主に見る．

.EXAMPLE
  pwsh -File tests/run_lua_tests.ps1
#>
[CmdletBinding()]
param([string]$Lua = '')

$ErrorActionPreference = 'Stop'
# 終了コードが0でない native コマンドで例外にしない (エラーの検査そのものが目的のため)．
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent $PSScriptRoot
if (-not $Lua) { $Lua = Join-Path $root '.claude/skills/build-poster-pdf/poster.lua' }
if (-not (Test-Path $Lua)) { throw "poster.lua が無い: $Lua" }
if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) { throw 'pandoc が見つからない．' }

$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('poster-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmpDir | Out-Null

$script:passed   = 0
$script:failures = @()

function Invoke-Poster([string]$md) {
  $f  = Join-Path $tmpDir 'case.md'
  $ef = Join-Path $tmpDir 'stderr.txt'
  Set-Content -LiteralPath $f -Value $md -Encoding UTF8
  $out = & pandoc $f '--from=markdown-implicit_figures' '--to=html5' "--lua-filter=$Lua" 2>$ef
  return @{
    Code = $LASTEXITCODE
    Out  = ($out -join "`n")
    Err  = ((Get-Content -LiteralPath $ef -Raw -ErrorAction SilentlyContinue) + '')
  }
}

function Test-Poster {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Md,
    [string[]]$Contains    = @(),   # 出力に必ずある文字列
    [string[]]$NotContains = @(),   # 出力にあってはいけない文字列
    [hashtable]$Count      = @{},   # 文字列 → 出てくる回数
    [string]$ErrorMatch    = '',    # これを含むエラーで止まるはず
    [string]$WarnMatch     = ''     # これを含む警告が出るはず (止まりはしない)
  )
  $r = Invoke-Poster $Md
  $bad = @()

  if ($ErrorMatch) {
    if ($r.Code -eq 0) {
      $bad += "エラーで止まるはずが通った (期待: $ErrorMatch)"
    } elseif ($r.Err -notmatch [regex]::Escape($ErrorMatch)) {
      $bad += "エラーの文面が違う (期待: $ErrorMatch / 実際: $($r.Err.Trim()))"
    }
  } elseif ($r.Code -ne 0) {
    $bad += "pandoc が失敗した: $($r.Err.Trim())"
  }

  if ($WarnMatch -and ($r.Err -notmatch [regex]::Escape($WarnMatch))) {
    $bad += "警告が出ていない (期待: $WarnMatch)"
  }
  foreach ($c in $Contains)    { if ($r.Out -notmatch [regex]::Escape($c)) { $bad += "出力に無い: $c" } }
  foreach ($c in $NotContains) { if ($r.Out -match    [regex]::Escape($c)) { $bad += "出力にある: $c" } }
  foreach ($k in $Count.Keys) {
    $n = ([regex]::Matches($r.Out, [regex]::Escape($k))).Count
    if ($n -ne $Count[$k]) { $bad += "$k の数が $n 個 (見込み $($Count[$k]) 個)" }
  }

  if ($bad.Count -eq 0) {
    $script:passed++
    Write-Host ('  ok   ' + $Name)
  } else {
    $script:failures += ($Name + "`n        - " + ($bad -join "`n        - "))
    Write-Host ('  FAIL ' + $Name) -ForegroundColor Red
  }
}

function Head([string]$s) { Write-Host ''; Write-Host $s -ForegroundColor Cyan }

# 各テストの md はこの前置きに本文を足して作る
# (`type` は ps1 側で見るものなので，フィルタのテストでは要らない)．
function New-Md([string]$header, [string]$body) { return "---`n$header---`n`n$body" }

# ============================================================ 表題帯
Head '表題帯 (ヘッダーから組み立てる)'

Test-Poster '表題だけなら表題帯に h1 だけが出る' (New-Md "title: My Poster`n" "# One`n`na`n") `
  -Contains 'class="title-band"', '<h1>My Poster</h1>' `
  -NotContains 'class="byline"', 'class="note"', 'class="subtitle"'

Test-Poster '表題が無ければ表題帯そのものが出ない' (New-Md "author: Jane`n" "# One`n`na`n") `
  -NotContains 'class="title-band"'

Test-Poster '副題・氏名・注記・ロゴが所定の順に並ぶ' `
  (New-Md "title: T`nsubtitle: S`nauthor: Jane Doe`ninstitute: Example Univ.`nnote: N`nlogo: logo.png`n" "# One`n`na`n") `
  -Contains '<div class="subtitle">', '<div class="byline">', '<div class="note">', '<div class="logo">',
            'Jane Doe(Example Univ.)', 'class="title-band has-logo"'

Test-Poster 'ロゴが無ければ has-logo は付かない' (New-Md "title: T`n" "# One`n`na`n") `
  -Contains 'class="title-band"' -NotContains 'has-logo'

Test-Poster '著者2人・所属1つは「A・B(所属)」' `
  (New-Md "title: T`nauthor: [A, B]`ninstitute: [U]`n" "# One`n`na`n") `
  -Contains 'A・B(U)'

Test-Poster '著者2人・所属2つは「A(U1)・B(U2)」' `
  (New-Md "title: T`nauthor: [A, B]`ninstitute: [U1, U2]`n" "# One`n`na`n") `
  -Contains 'A(U1)・B(U2)'

Test-Poster '姉妹ツールの別名キー (poster-authors / institutes / footer) を受ける' `
  (New-Md "title: T`nposter-authors: [A]`ninstitutes: [U]`nfooter: F`n" "# One`n`na`n") `
  -Contains 'A(U)', '<div class="note">', 'F'

# ============================================================ 箱への切り分け
Head '箱への切り分け'

Test-Poster '# ごとに1つの箱になる' (New-Md "title: T`n" "# One`n`na`n`n# Two`n`nb`n") `
  -Count @{ '<div class="box"' = 2; '<div class="box-title">' = 2; '<div class="box-body">' = 2 }

Test-Poster '最初の # より前の内容は捨てる' (New-Md "title: T`n" "捨てられる段落`n`n# One`n`na`n") `
  -Contains '<div class="box"' -NotContains '捨てられる段落'

Test-Poster '{.full} を付けた箱は class に full が入る' (New-Md "title: T`n" "# One {.full}`n`na`n") `
  -Contains 'class="box full"'

Test-Poster '見出しが1つも無ければ箱は0個' (New-Md "title: T`n" "本文だけ`n") `
  -Contains 'class="content flow"' -Count @{ '<div class="box"' = 0 }

# ============================================================ 図・リンク
Head '図とリンクの扱い'

Test-Poster '画像だけの段落は div.fig に包まれる' (New-Md "title: T`n" "# One`n`n![a](x.png)`n") `
  -Contains '<div class="fig">'

Test-Poster '::: row の中の画像も div.fig に包まれる' `
  (New-Md "title: T`n" "# One`n`n::: row`n`n![a](x.png)`n`n![b](y.png)`n`n:::`n") `
  -Count @{ '<div class="fig">' = 2 }

Test-Poster '文字と画像が混じった段落は div.fig にしない' (New-Md "title: T`n" "# One`n`n文と ![a](x.png)`n") `
  -NotContains '<div class="fig">'

Test-Poster '[メモ](x.png) は画像として救済する' (New-Md "title: T`n" "# One`n`n[メモ](x.png)`n") `
  -Contains '<img src="x.png"'

Test-Poster '画像でない拡張子のリンクは救済しない' (New-Md "title: T`n" "# One`n`n[頁](a.html)`n") `
  -Contains '<a href="a.html"' -NotContains '<img'

# ============================================================ 行末の改行
Head '行末の改行の詰め方'

Test-Poster '欧文どうしの境目には空白が残る' (New-Md "title: T`n" "# One`n`nplants,`nto clarify`n") `
  -Contains 'plants, to clarify' -NotContains 'plants,to clarify'

Test-Poster '和文どうしの境目は詰める' (New-Md "title: T`n" "# One`n`n和文は行末を`n詰めてよい．`n") `
  -Contains '和文は行末を詰めてよい．'

Test-Poster '和文と欧文の境目も詰める (和文の組版では空白を置かない)' `
  (New-Md "title: T`n" "# One`n`n発展している．`n2025年には…`n") `
  -Contains '発展している．2025年には…'

Test-Poster '半角の約物ごしでも和文なら詰める' (New-Md "title: T`n" "# One`n`n終わる行 (注記)`nの次の和文．`n") `
  -Contains '(注記)の次の和文．'

# ============================================================ 配置
Head '箱の配置'

Test-Poster 'layout も grid も無ければ流し込み (content flow)' (New-Md "title: T`n" "# One`n`na`n") `
  -Contains 'class="content flow"' -NotContains 'grid-template-areas'

Test-Poster 'layout があれば grid-template-areas を組む' `
  (New-Md "title: T`nlayout:`n  - [One, Two]`n" "# One`n`na`n`n# Two`n`nb`n") `
  -Contains 'class="content grid"', 'grid-template-columns: repeat(2, 1fr)',
            'grid-template-areas: &quot;one two&quot;', 'style="grid-area: one;"'

Test-Poster 'layout で同じ名前を2行に書くと縦に結合する' `
  (New-Md "title: T`nlayout:`n  - [One, Two]`n  - [Three, Two]`n" "# One`n`na`n`n# Two`n`nb`n`n# Three`n`nc`n") `
  -Contains 'grid-template-areas: &quot;one two&quot; &quot;three two&quot;'

Test-Poster 'layout の1要素だけの行は全幅に伸びる' `
  (New-Md "title: T`nlayout:`n  - [One, Two]`n  - [Three]`n" "# One`n`na`n`n# Two`n`nb`n`n# Three`n`nc`n") `
  -Contains 'grid-template-areas: &quot;one two&quot; &quot;three three&quot;'

Test-Poster 'grid は座標をそのまま grid-column / grid-row にする (0 起点)' `
  (New-Md "title: T`ngrid:`n  columns: 2`n  boxes:`n    - {name: One, x: 0, y: 0}`n    - {name: Two, x: 1, y: 1, w: 1, h: 2}`n" "# One`n`na`n`n# Two`n`nb`n") `
  -Contains 'style="grid-column: 1 / span 1; grid-row: 1 / span 1;"',
            'style="grid-column: 2 / span 1; grid-row: 2 / span 2;"'

Test-Poster 'grid の w・h を省くと1になる' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: One, x: 0, y: 0}`n" "# One`n`na`n") `
  -Contains 'grid-column: 1 / span 1; grid-row: 1 / span 1;'

Test-Poster 'grid と layout を両方書いたら警告して grid を使う' `
  (New-Md "title: T`nlayout:`n  - [One]`ngrid:`n  columns: 1`n  boxes:`n    - {name: One, x: 0, y: 0}`n" "# One`n`na`n") `
  -WarnMatch 'grid: と layout: の両方がある' -Contains 'grid-column: 1 / span 1'

# ============================================================ 書き間違いを止める
Head '書き間違いをエラーで止める'

Test-Poster 'layout の見出し名が本文に無い' `
  (New-Md "title: T`nlayout:`n  - [NoSuch]`n" "# One`n`na`n") `
  -ErrorMatch 'layout の見出し名が本文に無い'

Test-Poster '本文の見出しが layout に無い' `
  (New-Md "title: T`nlayout:`n  - [One]`n" "# One`n`na`n`n# Two`n`nb`n") `
  -ErrorMatch 'が layout に無い'

Test-Poster 'grid の見出し名が本文に無い' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: NoSuch, x: 0, y: 0}`n" "# One`n`na`n") `
  -ErrorMatch 'grid.boxes の見出し名が本文に無い'

Test-Poster '本文の見出しが grid.boxes に無い' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: One, x: 0, y: 0}`n" "# One`n`na`n`n# Two`n`nb`n") `
  -ErrorMatch 'が grid.boxes に無い'

Test-Poster 'grid の箱どうしが同じマスで重なる' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: One, x: 0, y: 0}`n    - {name: Two, x: 0, y: 0}`n" "# One`n`na`n`n# Two`n`nb`n") `
  -ErrorMatch 'が同じマス'

Test-Poster 'grid の箱が右へはみ出す' `
  (New-Md "title: T`ngrid:`n  columns: 2`n  boxes:`n    - {name: One, x: 1, y: 0, w: 2}`n" "# One`n`na`n") `
  -ErrorMatch 'が右へはみ出している'

Test-Poster 'grid に boxes が無い' (New-Md "title: T`ngrid:`n  columns: 2`n" "# One`n`na`n") `
  -ErrorMatch 'grid: には boxes のリストが要る'

Test-Poster 'grid.boxes の要素に name が無い' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {x: 0, y: 0}`n" "# One`n`na`n") `
  -ErrorMatch 'grid.boxes の要素に name が無い'

# --- 2026-09-02 に足した検査 (それまでは黙って別物の配置になっていた) ---

Test-Poster '座標が小数なら止める (0.9 を黙って 0 にしない)' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: One, x: 0.9, y: 0}`n" "# One`n`na`n") `
  -ErrorMatch 'の x は整数で書く'

Test-Poster '座標が数値でなければ止める (既定値に落とさない)' `
  (New-Md "title: T`ngrid:`n  boxes:`n    - {name: One, x: いち, y: 0}`n" "# One`n`na`n") `
  -ErrorMatch 'の x は整数で書く'

Test-Poster 'grid.columns が数値でなければ止める' `
  (New-Md "title: T`ngrid:`n  columns: たくさん`n  boxes:`n    - {name: One, x: 0, y: 0}`n" "# One`n`na`n") `
  -ErrorMatch 'grid.columns は整数で書く'

Test-Poster 'grid.boxes に同じ名前が2回あれば止める' `
  (New-Md "title: T`ngrid:`n  columns: 2`n  boxes:`n    - {name: One, x: 0, y: 0}`n    - {name: One, x: 1, y: 1}`n" "# One`n`na`n") `
  -ErrorMatch 'が2回ある'

Test-Poster 'layout の重複が長方形でなければ止める' `
  (New-Md "title: T`nlayout:`n  - [One, Two]`n  - [Two, One]`n" "# One`n`na`n`n# Two`n`nb`n") `
  -ErrorMatch 'が長方形になっていない'

Test-Poster 'layout の縦の結合 (長方形) は通る' `
  (New-Md "title: T`nlayout:`n  - [One, Two]`n  - [Three, Two]`n" "# One`n`na`n`n# Two`n`nb`n`n# Three`n`nc`n") `
  -Contains 'grid-area: two;'

Test-Poster 'layout の行の要素数が列数を割り切れない' `
  (New-Md "title: T`nlayout:`n  - [One, Two, Three]`n  - [Four, Five]`n" "# One`n`na`n`n# Two`n`nb`n`n# Three`n`nc`n`n# Four`n`nd`n`n# Five`n`ne`n") `
  -ErrorMatch '割り切れない'

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
