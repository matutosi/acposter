-- 学術ポスター (A0/A1・1枚) の md を組むための pandoc Lua フィルタ．
--
-- 1. ヘッダー (YAML front matter) の title / subtitle / author / institute / note / logo
--    から表題帯を作る．author は authors・poster-authors，institute は institutes・
--    affiliation(s)，note は funding・footer でも書ける
--    (ggposter・qtposter と同じ名前を受けるため)．
-- 2. `# ` ごとに1つの緑角丸枠 (div.box) へ切り分ける (スライドの「1枚」がポスターでは「1枠」になる)．
-- 3. ヘッダーに `layout:` (見出し名の行列) があれば CSS Grid の配置に，無ければ既定の
--    段組み流し込み (CSS columns) に切り替える．
-- 4. 画像だけの段落に div.fig を付ける (p を残すと img の max-width が効かない罠を避ける)．
-- 5. `[文字列](画像.png)` のような書き間違い (本来 `![...]` とすべきリンク記法) を画像として救済する．
-- 6. 和文が絡む境目では行末の改行を詰める (md は1文1行で書いてよい)．
--    欧文どうしの境目にだけ空白を残す (詰めると単語がくっつく)．

-- 文字列を Inlines へ (空白で分けて Str と Space を並べる)
local function to_inlines(s)
  local out, first = {}, true
  for w in s:gmatch('%S+') do
    if not first then out[#out + 1] = pandoc.Space() end
    out[#out + 1] = pandoc.Str(w)
    first = false
  end
  return out
end

-- メタデータの値を文字列のリストへ (1つでもリストでも受ける)
local function is_list(v)
  if pandoc.utils.type then return pandoc.utils.type(v) == 'List' end
  return type(v) == 'table' and v.t == 'MetaList'
end

-- YAML の連想配列 (MetaMap) か．
-- **`pandoc.utils.type()` は MetaMap に対して 'Map' ではなく 'table' を返す**
-- (2026-08-30 に実機で確認．'Map' で判定すると常に false になり，`grid:` が
-- 黙って無視されて既定の流し込みに落ちる)．リスト・文字列を除いた table とみなす．
local function is_map(v)
  if type(v) ~= 'table' then return false end
  local t = pandoc.utils.type and pandoc.utils.type(v) or nil
  if t == 'List' or t == 'Inlines' or t == 'Blocks' then return false end
  return true
end

-- メタデータの値を数値へ (無ければ既定値)．
-- **書き間違いを黙って既定値に落とさない** (2026-09-02)．それまでは
-- `x: 0.9` が math.floor で 0 に，`x: なにか` が既定値の 0 になり，
-- 警告も出ないまま別の場所へ置かれていた．
local function to_num(v, default, what)
  if v == nil then return default end
  local s = pandoc.utils.stringify(v)
  local n = tonumber(s)
  if n == nil or n ~= math.floor(n) then
    error(('%s は整数で書く (今は "%s")．'):format(what, s))
  end
  return math.floor(n)
end

local function to_list(v)
  local out = {}
  if v == nil then return out end
  if is_list(v) then
    for _, e in ipairs(v) do
      local s = pandoc.utils.stringify(e)
      if s ~= '' then out[#out + 1] = s end
    end
  else
    local s = pandoc.utils.stringify(v)
    if s ~= '' then out[#out + 1] = s end
  end
  return out
end

-- 姉妹ツール (ggposter・qtposter) が同じ意味に使っているキー名も受ける．
-- 名前が違うだけで中身は同じなので，ヘッダーを書き換えずに移し替えられるようにする．
-- 先に書いてある名前 (正) を優先し，無ければ別名を順に見る．
local function meta_alias(meta, names)
  for _, k in ipairs(names) do
    local v = meta[k]
    if v ~= nil then
      local list = to_list(v)
      if #list > 0 then return list end
    end
  end
  return {}
end

-- 「氏名(所属)」の行を作る (build-abstract-pdf の abstract.lua と同じロジック)
local function make_byline(meta)
  local authors = meta_alias(meta, { 'author', 'authors', 'poster-authors' })
  local affils  = meta_alias(meta, { 'institute', 'institutes',
                                     'affiliation', 'affiliations' })
  if #authors == 0 then return nil end
  if #affils == 0 then return table.concat(authors, '・') end
  if #affils == 1 then
    return table.concat(authors, '・') .. '(' .. affils[1] .. ')'
  end
  local parts = {}
  for i, a in ipairs(authors) do
    parts[#parts + 1] = a .. '(' .. (affils[i] or affils[#affils]) .. ')'
  end
  return table.concat(parts, '・')
end

-- CSS の grid-area / class に使える slug (ASCII のみ．和文見出しは box-1, box-2 … に落ちる)
local slug_seen = {}
local function to_slug(s)
  local t = s:lower():gsub('[^%w]+', '-'):gsub('^%-+', ''):gsub('%-+$', '')
  if t == '' then t = 'box' end
  if slug_seen[t] then
    local n = 2
    while slug_seen[t .. '-' .. n] do n = n + 1 end
    t = t .. '-' .. n
  end
  slug_seen[t] = true
  return t
end

-- 見出し文字列どうしの突き合わせ用 (前後空白を詰め，連続空白を1つに，小文字化)
local function normalize(s)
  return s:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' '):lower()
end

-- 見出し名 (正規化ずみ) から箱を引く表．`grid:` と `layout:` の両方で使う．
local function index_by_name(boxes)
  local by_name = {}
  for _, bx in ipairs(boxes) do by_name[normalize(bx.name)] = bx end
  return by_name
end

-- 画像だけの段落か (画像と空白以外が無い)
local function is_figure(blk)
  if blk.t ~= 'Para' then return false end
  local n = 0
  for _, il in ipairs(blk.content) do
    if il.t == 'Image' then
      n = n + 1
    elseif il.t ~= 'Space' and il.t ~= 'SoftBreak' then
      return false
    end
  end
  return n > 0
end

-- 画像だけの段落は div.fig で包み，中の p を外す (build-slide-pdf の slide.lua と同じ対策)
local function para_class(blk)
  if is_figure(blk) then
    return pandoc.Div(pandoc.Plain(blk.content), pandoc.Attr('', { 'fig' }))
  end
  return blk
end

-- 箱の中身を順に処理する．Div (`::: row` など) の中も再帰して見る必要がある。
-- そうしないと `::: row` の中の画像段落が div.fig に包まれず，max-height が効かない
-- (2026-08-29 のフルコンテンツ検証で発見)．
local function process_blocks(blocks)
  local out = {}
  for _, b in ipairs(blocks) do
    if b.t == 'Div' then
      out[#out + 1] = pandoc.Div(process_blocks(b.content), b.attr)
    else
      out[#out + 1] = para_class(b)
    end
  end
  return out
end

local IMAGE_EXT = { png = true, jpg = true, jpeg = true, gif = true, svg = true, webp = true }

-- `[メモ](filename.png)` のような書き間違い (画像記法 `![...]` の付け忘れ) を画像として救済する
function Link(el)
  local ext = el.target:match('%.([%a]+)$')
  if ext and IMAGE_EXT[ext:lower()] then
    return pandoc.Image(el.content, el.target, el.title, el.attr)
  end
  return nil
end

-- 行末の改行 (SoftBreak) の詰め方．**和文が絡む境目は詰め，欧文どうしの境目にだけ空白を残す**．
-- 無条件に落とすと，1文1行で書いた英文が単語ごとくっつく
-- ("plants,to clarify"・"availability oflong-established")．
-- 2026-09-02 まで無条件に落としており，examples/golf_course.pdf に実際に出ていた．
local CJK_RANGES = {
  { 0x3000, 0x303F },   -- CJK の約物 (、。「」)
  { 0x3040, 0x30FF },   -- ひらがな・カタカナ (・ を含む)
  { 0x31F0, 0x31FF },   -- カタカナ拡張
  { 0x3400, 0x4DBF },   -- 漢字 拡張A
  { 0x4E00, 0x9FFF },   -- 漢字
  { 0xF900, 0xFAFF },   -- 互換漢字
  { 0xFF00, 0xFF60 },   -- 全角の英数・約物 (，．()「」)
  { 0xFFE0, 0xFFE6 },   -- 全角の記号
}

local function is_cjk(cp)
  if cp == nil then return false end
  for _, r in ipairs(CJK_RANGES) do
    if cp >= r[1] and cp <= r[2] then return true end
  end
  return false
end

-- 半角の約物・空白は「透ける」ものとして飛ばす．和文でも丸括弧・記号は半角で書くので
-- (ユーザの表記ルール)，`…と)` の `)` だけを見て「和文ではない」と判じないため．
-- 欧文で飛ばしても，その奥に出てくるのはラテン文字なので判定は変わらない．
local function is_transparent(cp)
  return cp == 0x20 or cp == 0x09
      or (cp >= 0x21 and cp <= 0x2F) or (cp >= 0x3A and cp <= 0x40)
      or (cp >= 0x5B and cp <= 0x60) or (cp >= 0x7B and cp <= 0x7E)
end

-- 隣の要素の「境目の文字」の符号位置を返す (last なら末尾から，そうでなければ先頭から)．
-- Emph や Code に包まれていても中の文字が見えるよう stringify を通す．
local function edge_cp(il, last)
  if il == nil then return nil end
  local ok, s = pcall(pandoc.utils.stringify, il)
  if not ok or s == nil or s == '' then return nil end
  local cps = {}
  for _, c in utf8.codes(s) do cps[#cps + 1] = c end
  local from, to, step = 1, #cps, 1
  if last then from, to, step = #cps, 1, -1 end
  for i = from, to, step do
    if not is_transparent(cps[i]) then return cps[i] end
  end
  return nil
end

function Inlines(ils)
  local has_softbreak = false
  for _, il in ipairs(ils) do
    if il.t == 'SoftBreak' then has_softbreak = true; break end
  end
  if not has_softbreak then return nil end

  local out = pandoc.Inlines({})
  for i, il in ipairs(ils) do
    if il.t == 'SoftBreak' then
      -- **どちらか一方でも和文なら詰める**．空白を入れるのは両側とも欧文のときだけ
      -- (pandoc の既定の書き出しと同じ振る舞い)．和文と欧文の境目は，和文の組版では
      -- 空白を置かない．「ともに和文のときだけ詰める」にすると，
      -- 「…である．⏎2025年には…」が「である． 2025年」になってしまう
      -- (2026-09-02 に実際の要旨の原稿で見つけた)．
      if not (is_cjk(edge_cp(ils[i - 1], true)) or is_cjk(edge_cp(ils[i + 1], false))) then
        out:insert(pandoc.Space())
      end
    else
      out:insert(il)
    end
  end
  return out
end

-- Pandoc は要素ごとのフィルタ (Link / Inlines) のあとに1度だけ走る．
function Pandoc(doc)
  -- `# ` ごとに1つの箱へ切り分ける (最初の `# ` より前の内容は捨てる)
  local boxes, cur = {}, nil
  for _, b in ipairs(doc.blocks) do
    if b.t == 'Header' and b.level == 1 then
      cur = { name = pandoc.utils.stringify(b.content), full = b.classes:includes('full'), blocks = {} }
      boxes[#boxes + 1] = cur
    elseif cur then
      cur.blocks[#cur.blocks + 1] = b
    end
  end

  local out = {}

  -- 表題帯 (ヘッダーから組み立てる．本文の `# ` は使わない)
  local title = pandoc.utils.stringify(doc.meta.title or '')
  if title ~= '' then
    local head = { pandoc.Header(1, to_inlines(title)) }
    -- 副題は表題のすぐ下 (ggposter の title.subtitle・qtposter の subtitle と同じ位置)
    local subtitle = table.concat(meta_alias(doc.meta, { 'subtitle' }), ' ')
    if subtitle ~= '' then
      head[#head + 1] = pandoc.Div(pandoc.Para(to_inlines(subtitle)),
                                   pandoc.Attr('', { 'subtitle' }))
    end
    local byline = make_byline(doc.meta)
    if byline then
      head[#head + 1] = pandoc.Div(pandoc.Para(to_inlines(byline)), pandoc.Attr('', { 'byline' }))
    end
    local note = table.concat(meta_alias(doc.meta, { 'note', 'funding', 'footer' }), ' ')
    if note ~= '' then
      head[#head + 1] = pandoc.Div(pandoc.Para(to_inlines(note)), pandoc.Attr('', { 'note' }))
    end
    -- ロゴは表題帯の右端に重ねる (CSS で位置を決める)．表題の中央揃えを崩さないため，
    -- 帯の中の最後に置いて absolute で逃がす．複数書けば左から順に並ぶ．
    local logos = meta_alias(doc.meta, { 'logo', 'logos' })
    local band_classes = { 'title-band' }
    if #logos > 0 then
      local imgs = {}
      for _, src in ipairs(logos) do
        imgs[#imgs + 1] = pandoc.Image({}, src)
      end
      head[#head + 1] = pandoc.Div(pandoc.Plain(imgs), pandoc.Attr('', { 'logo' }))
      -- ロゴは absolute なので場所を取らない．長い表題がロゴの下へ潜り込まないよう，
      -- ロゴがあるときだけ帯の左右の余白を広げる (左右そろえて表題の中央を保つ)．
      band_classes[#band_classes + 1] = 'has-logo'
    end
    out[#out + 1] = pandoc.Div(head, pandoc.Attr('', band_classes))
  end

  -- 箱の配置の決め方は3通り (上から順に見て，最初に見つかったものを使う)．
  --   1. `grid:` (座標指定)     … 各箱の x/y/w/h をそのまま CSS Grid の位置にする
  --   2. `layout:` (見出しの行列) … 見た目どおりに並べた表から grid-template-areas を組む
  --   3. どちらも無ければ         … CSS columns の段組み流し込み (新聞調)
  local grid_meta   = doc.meta.grid
  local layout_meta = doc.meta.layout
  local content_attr

  -- 両方書いてあるときは `grid:` を使うが，**黙って無視すると書き間違いに気づけない**
  -- ので警告する (2026-08-30 に追加．エラーにはしない．どちらか一方を消せば消える)．
  if grid_meta and is_map(grid_meta) and layout_meta and is_list(layout_meta) then
    io.stderr:write(
      '[warning] ヘッダーに grid: と layout: の両方がある．grid: (座標指定) を使い，' ..
      'layout: (見出しの行列) は無視する．使わないほうを消す．\n')
  end

  if grid_meta and is_map(grid_meta) then
    -- --- 1. 座標指定 (gridstack.js 風の x/y/w/h) -----------------------------
    local cols = to_num(grid_meta.columns, 2, 'grid.columns')
    if cols < 1 then error('grid.columns は1以上にする (今は ' .. cols .. ')．') end

    local items = grid_meta.boxes
    if not (items and is_list(items)) then
      error('grid: には boxes のリストが要る (例: boxes: [{name: OBJECTIVES, x: 0, y: 0}])．')
    end

    local by_name = index_by_name(boxes)
    local matched = {}
    local used = {}   -- 重なりの検査用 ("x,y" → 見出し名)
    local seen = {}   -- 名前の重複の検査用 (正規化した見出し名 → 書いてあった名前)

    for _, item in ipairs(items) do
      if not is_map(item) then
        error('grid.boxes の要素は {name: ..., x: ..., y: ...} の形にする．')
      end
      local nm = pandoc.utils.stringify(item.name or '')
      if nm == '' then error('grid.boxes の要素に name が無い．') end
      local bx = by_name[normalize(nm)]
      if not bx then
        error('grid.boxes の見出し名が本文に無い: "' .. nm .. '"．`# ` の見出しと一字一句 (空白は詰めて) 揃える．')
      end
      -- 同じ名前を2回書くと**後に書いたほうだけが残り，先の座標が黙って消える**
      -- (別のマスなら重なりの検査もすり抜ける)．2026-09-02 に検査を足した．
      if seen[normalize(nm)] then
        error(('grid.boxes に "%s" が2回ある．1つの見出しは1回だけ書く (縦・横に伸ばすのは h・w)．'):format(nm))
      end
      seen[normalize(nm)] = nm
      matched[bx] = true

      local x = to_num(item.x, 0, ('grid.boxes の "%s" の x'):format(nm))
      local y = to_num(item.y, 0, ('grid.boxes の "%s" の y'):format(nm))
      local w = to_num(item.w, 1, ('grid.boxes の "%s" の w'):format(nm))
      local h = to_num(item.h, 1, ('grid.boxes の "%s" の h'):format(nm))
      if x < 0 or y < 0 then error('grid.boxes の x・y は0以上にする ("' .. nm .. '")．') end
      if w < 1 or h < 1 then error('grid.boxes の w・h は1以上にする ("' .. nm .. '")．') end
      if x + w > cols then
        error(('"%s" が右へはみ出している (x=%d, w=%d, columns=%d)．'):format(nm, x, w, cols))
      end
      -- 重なりを見つけたらエラーにする (黙って重ねて読めなくなるのを防ぐ)
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do
          local key = (x + dx) .. ',' .. (y + dy)
          if used[key] then
            error(('"%s" と "%s" が同じマス (x=%d, y=%d) で重なっている．'):format(used[key], nm, x + dx, y + dy))
          end
          used[key] = nm
        end
      end

      bx.slug = to_slug(bx.name)
      -- CSS Grid は1始まりなので +1 する
      bx.grid_style = ('grid-column: %d / span %d; grid-row: %d / span %d;'):format(x + 1, w, y + 1, h)
    end

    for _, bx in ipairs(boxes) do
      if not matched[bx] then
        error('本文の見出し "' .. bx.name .. '" が grid.boxes に無い．全ての見出しを1回ずつ書く．')
      end
    end

    content_attr = pandoc.Attr('', { 'content', 'grid' }, {
      { 'style', ('display:grid; grid-template-columns: repeat(%d, 1fr);'):format(cols) }
    })
  elseif layout_meta and is_list(layout_meta) then
    local by_name = index_by_name(boxes)
    local matched = {}
    local rows, max_cols = {}, 0
    for _, row in ipairs(layout_meta) do
      local names = to_list(row)
      if #names == 0 and pandoc.utils.type(row) ~= 'List' then names = { pandoc.utils.stringify(row) } end
      local slugs = {}
      for _, nm in ipairs(names) do
        local bx = by_name[normalize(nm)]
        if not bx then
          error('layout の見出し名が本文に無い: "' .. nm .. '"．`# ` の見出しと一字一句 (空白は詰めて) 揃える．')
        end
        matched[bx] = true
        slugs[#slugs + 1] = bx.slug or (function() bx.slug = to_slug(bx.name); return bx.slug end)()
      end
      rows[#rows + 1] = slugs
      if #slugs > max_cols then max_cols = #slugs end
    end
    for _, bx in ipairs(boxes) do
      if not matched[bx] then
        error('本文の見出し "' .. bx.name .. '" が layout に無い．layout に全ての見出しを1回ずつ書く．')
      end
    end
    local cell_rows = {}
    for _, slugs in ipairs(rows) do
      if #slugs == 0 then error('layout に空の行がある．使わない行は消す．') end
      if max_cols % #slugs ~= 0 then
        error('layout の行の要素数 (' .. #slugs .. ') が列数 (' .. max_cols .. ') を割り切れない．')
      end
      local span = max_cols // #slugs
      local cells = {}
      for _, s in ipairs(slugs) do
        for _ = 1, span do cells[#cells + 1] = s end
      end
      cell_rows[#cell_rows + 1] = cells
    end

    -- 同じ名前を何行にも書いて縦に結合できるが，**長方形にならないと
    -- grid-template-areas が不正になり，ブラウザが宣言ごと捨てる**
    -- (箱が勝手な位置へ散り，別物の配置の PDF ができてしまう)．
    -- 2026-09-02 まで検査が無く，SKILL.md の「長方形になるように書く」に頼っていた．
    local span_of = {}
    for r, cells in ipairs(cell_rows) do
      for c, s in ipairs(cells) do
        local b = span_of[s]
        if b == nil then
          span_of[s] = { r1 = r, r2 = r, c1 = c, c2 = c, n = 1 }
        else
          if r < b.r1 then b.r1 = r end
          if r > b.r2 then b.r2 = r end
          if c < b.c1 then b.c1 = c end
          if c > b.c2 then b.c2 = c end
          b.n = b.n + 1
        end
      end
    end
    for _, bx in ipairs(boxes) do
      local b = span_of[bx.slug]
      if b and b.n ~= (b.r2 - b.r1 + 1) * (b.c2 - b.c1 + 1) then
        error(('layout の "%s" が長方形になっていない．同じ見出しは続いた行・列に固めて書く．'):format(bx.name))
      end
    end

    local area_rows = {}
    for _, cells in ipairs(cell_rows) do
      area_rows[#area_rows + 1] = '"' .. table.concat(cells, ' ') .. '"'
    end
    content_attr = pandoc.Attr('', { 'content', 'grid' }, {
      { 'style', ('display:grid; grid-template-columns: repeat(%d, 1fr); grid-template-areas: %s;')
        :format(max_cols, table.concat(area_rows, ' ')) }
    })
  else
    for _, bx in ipairs(boxes) do bx.slug = to_slug(bx.name) end
    content_attr = pandoc.Attr('', { 'content', 'flow' })
  end

  -- 箱を組み立てる
  local content_blocks = {}
  for _, bx in ipairs(boxes) do
    local body = process_blocks(bx.blocks)
    local classes = { 'box' }
    if bx.full then classes[#classes + 1] = 'full' end
    local keyvals = {}
    if bx.grid_style then
      -- 座標指定 (`grid:`) の箱は，計算した grid-column / grid-row をそのまま当てる
      keyvals = { { 'style', bx.grid_style } }
    elseif content_attr.classes:includes('grid') then
      -- 行列指定 (`layout:`) の箱は，grid-template-areas の区画名で置く
      keyvals = { { 'style', 'grid-area: ' .. bx.slug .. ';' } }
    end
    local parts = {
      pandoc.Div(pandoc.Plain(to_inlines(bx.name)), pandoc.Attr('', { 'box-title' })),
      pandoc.Div(body, pandoc.Attr('', { 'box-body' })),
    }
    content_blocks[#content_blocks + 1] = pandoc.Div(parts, pandoc.Attr('', classes, keyvals))
  end
  out[#out + 1] = pandoc.Div(content_blocks, content_attr)

  return pandoc.Pandoc(out, doc.meta)
end
