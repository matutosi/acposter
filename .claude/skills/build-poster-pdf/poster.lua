-- 学術ポスター (A0/A1・1枚) の md を組むための pandoc Lua フィルタ．
--
-- 1. ヘッダー (YAML front matter) の title / author / institute / note から表題帯を作る．
-- 2. `# ` ごとに1つの緑角丸枠 (div.box) へ切り分ける (スライドの「1枚」がポスターでは「1枠」になる)．
-- 3. ヘッダーに `layout:` (見出し名の行列) があれば CSS Grid の配置に，無ければ既定の
--    段組み流し込み (CSS columns) に切り替える．
-- 4. 画像だけの段落に div.fig を付ける (p を残すと img の max-width が効かない罠を避ける)．
-- 5. `[文字列](画像.png)` のような書き間違い (本来 `![...]` とすべきリンク記法) を画像として救済する．
-- 6. 和文は行末の改行を詰める (md は1文1行で書いてよい)．

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

-- 「氏名(所属)」の行を作る (build-abstract-pdf の abstract.lua と同じロジック)
local function make_byline(meta)
  local authors = to_list(meta.author)
  local affils  = to_list(meta.institute)
  if #affils == 0 then affils = to_list(meta.affiliation) end
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

function SoftBreak()
  return {}
end

-- Pandoc は要素ごとのフィルタ (Link / SoftBreak) のあとに1度だけ走る．
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
    local byline = make_byline(doc.meta)
    if byline then
      head[#head + 1] = pandoc.Div(pandoc.Para(to_inlines(byline)), pandoc.Attr('', { 'byline' }))
    end
    local note = pandoc.utils.stringify(doc.meta.note or '')
    if note ~= '' then
      head[#head + 1] = pandoc.Div(pandoc.Para(to_inlines(note)), pandoc.Attr('', { 'note' }))
    end
    out[#out + 1] = pandoc.Div(head, pandoc.Attr('', { 'title-band' }))
  end

  -- layout (見出し名の行列) があれば CSS Grid，無ければ既定の段組み流し込み
  local layout_meta = doc.meta.layout
  local content_attr
  if layout_meta and is_list(layout_meta) then
    local by_name = {}
    for _, bx in ipairs(boxes) do by_name[normalize(bx.name)] = bx end
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
    local area_rows = {}
    for _, slugs in ipairs(rows) do
      if max_cols % #slugs ~= 0 then
        error('layout の行の要素数 (' .. #slugs .. ') が列数 (' .. max_cols .. ') を割り切れない．')
      end
      local span = max_cols / #slugs
      local cells = {}
      for _, s in ipairs(slugs) do
        for _ = 1, span do cells[#cells + 1] = s end
      end
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
    if content_attr.classes:includes('grid') then
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
