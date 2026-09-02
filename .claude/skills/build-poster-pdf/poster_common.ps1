<#
.SYNOPSIS
  make_poster_pdf.ps1 の純関数をまとめたもの (単体テスト用の切れ目)．

.DESCRIPTION
  ファイルの読み書きと文字列の組み立てだけを行い，pandoc も Chrome も呼ばない
  関数をここに置く．make_poster_pdf.ps1 から dot source で読み込み，
  tests/run_ps1_tests.ps1 からも同じものを読み込んで確かめる (2026-09-02 に分離)．
  ここに置くのは**外の世界に触れないもの**だけにする (触れるものはテストの意味が薄れる)．
#>

# --- ヘッダー (YAML front matter) を読む -------------------------------------
# 先頭の `---` から次の `---` までを浅く読む (YAML の全体を解釈はしない)．
# **字下げのある行は入れ子** (`grid:` の下の `columns:` など) なので採らない．
function Get-FrontMatter([string]$path) {
  $lines = Get-Content -LiteralPath $path -Encoding UTF8
  if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
  $fm = [ordered]@{}
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { return $fm }
    if ($lines[$i] -match '^\s*#') { continue }
    if ($lines[$i] -match '^([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$') {
      $fm[$matches[1]] = $matches[2].Trim().Trim('"', "'")
    }
  }
  return $fm
}

# ヘッダーから最初に見つかった値を返す (別名を順に見る)．
function Get-MetaValue($fm, [string[]]$names) {
  if ($null -eq $fm) { return $null }
  foreach ($n in $names) {
    if ($fm.Contains($n) -and "$($fm[$n])" -ne '') { return "$($fm[$n])" }
  }
  return $null
}

# 引数とヘッダーの両方に書いてあったら**引数を採る** (その場の上書きの意図が強いため)．
# ただし**黙って捨てない** — 値が食い違うときは grid:/layout: の併記と同じく警告を出す．
#
# **検査は値の出どころで分けない** (2026-09-02)．それまではヘッダーの値だけを検査して
# いたので，引数で書くと素通りしていた．`-Font 'serif, } .box { display: none'` が
# CSS に差し込まれて**箱が全部消え**，`-FontSize 30` (単位なし)・`-Columns 0` は
# 無効な CSS になって黙って既定値に落ちていた．いまは同じ $Check を両方に通す．
#
#   $Check は「値を検査し，正規化した値を返す」．不正なら理由を throw する．
#   $Bound は呼び出し元の $PSBoundParameters (引数を「明示したか」を見る)．
#   $FromHeader・$Overridden は呼び出し元が用意する ArrayList で，表示用の控えを足す．
function Resolve-Setting {
  param(
    [Parameter(Mandatory)][string]$Key,        # ヘッダーの正のキー名 (表示にも使う)
    [string[]]$Alias = @(),                    # 同じ意味で受ける別名
    [Parameter(Mandatory)][string]$Param,      # 対応する引数の名前
    $Current,                                  # 引数の現在値
    [Parameter(Mandatory)][scriptblock]$Check,
    $Fm,
    $Bound = @{},
    [System.Collections.ArrayList]$FromHeader,
    [System.Collections.ArrayList]$Overridden
  )
  $explicit = $Bound.ContainsKey($Param) -and "$Current" -ne ''
  $value    = $Current
  if ($explicit) {
    try { $value = & $Check $Current }
    catch { throw ('-{0} が不正: {1} ({2})' -f $Param, $Current, $_.Exception.Message) }
  }

  $raw = Get-MetaValue $Fm (@($Key) + $Alias)
  if ($null -eq $raw) { return $value }

  # ヘッダーの値は，引数で上書きされる場合でも**必ず検査する**
  # (`paper: A2` のような書き間違いは `-Size A0` を付けていてもエラーで止まる)．
  try { $hdr = & $Check $raw }
  catch { throw ('ヘッダーの {0} が不正: {1} ({2})' -f $Key, $raw, $_.Exception.Message) }

  if ($explicit) {
    if ("$hdr" -ne "$value" -and $null -ne $Overridden) {
      [void]$Overridden.Add(('{0} (ヘッダー {1} / 引数 -{2} {3})' -f $Key, $hdr, $Param, $value))
    }
    return $value
  }
  if ($null -ne $FromHeader) { [void]$FromHeader.Add("$Key=$hdr") }
  return $hdr
}

# ローカルのパスを file:// URL にする．
# Mac/Linux の絶対パスは元から '/' で始まるので 'file://' + パス で3本スラッシュになる．
# Windows は 'D:\...' の形なので '/' に変えてから 'file:///' を付ける (4本目は不要)．
# **`[Uri]` クラスに任せるのは避ける**: Windows 上の pwsh で試したところ，Unix 形式の
# パスの扱いが読みにくかった (2026-08-29)．確実に検証できる自前の分岐にする．
#
# **URL に使えない文字は逃がす**．空白を含むパス ('C:\my poster\x.tmp.html') を
# そのまま渡すと，Start-Process が引数を割ってしまい Chrome が
# "Multiple targets are not supported in headless mode." で落ちる
# (2026-09-02 に再現)．`#`・`?` はそこで URL が切れるので同じく逃がす．
function ConvertTo-FileUrl([string]$path) {
  $p = if ($path.StartsWith('/')) { $path } else { '/' + $path.Replace([char]92, '/') }
  $p = $p.Replace('%', '%25').Replace('#', '%23').Replace('?', '%3F').Replace(' ', '%20')
  return 'file://' + $p
}
