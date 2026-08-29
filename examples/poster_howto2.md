---
title: "build-poster-pdf: input to output"
author: ["A cheat sheet of the build-poster-pdf syntax"]
institute: ["build-poster-pdf"]
type: "学術ポスター"
note: "Left column: what you write in the .md. Right column: what comes out. See poster_howto.md for a feature tour instead."
layout:
  - [Header input, Header output]
  - [Bullet list input, Bullet list output]
  - [Table input, Table output]
  - [Figure input, Figure output]
  - [Layout 2 columns input, Layout 2 columns output]
  - [Layout 1 column input, Layout 1 column output]
---

# Header input

```
---
title: "My Poster"
author: ["Jane Doe"]
institute: ["Example Univ."]
note: "A short note"
type: "学術ポスター"
---
```

# Header output

<div style="font-size:0.6em;">
<div class="title-band">
<h1>My Poster</h1>
<div class="byline"><p>Jane Doe(Example Univ.)</p></div>
<div class="note"><p>A short note</p></div>
</div>
</div>

The title band always spans the full width, above every box.

# Bullet list input

```
- First point
- Second point
  - Nested point
```

# Bullet list output

- First point
- Second point
  - Nested point

# Table input

```
| Item | Value |
|---|---|
| A | 1 |
| B | 2 |
```

# Table output

| Item | Value |
|---|---|
| A | 1 |
| B | 2 |

# Figure input

```
![Figure example](../images/howto_fig.png)
```

# Figure output

![Figure example](../images/howto_fig.png)

# Layout 2 columns input

No `layout:` key, so boxes flow newspaper-style (left column top to bottom,
then the right column).

```
---
title: "..."
---
# BOX A
...
# BOX B
...
# BOX C
...
```

# Layout 2 columns output

Boxes fill the left column first, then the right column.

<div style="display:flex; gap:0.6em; margin:0.3em 0 0;">
<div style="flex:1; display:flex; flex-direction:column; gap:0.4em;">
<div style="border:0.12em solid var(--box-color); border-radius:0.5em; padding:0.4em; text-align:center;">A</div>
<div style="border:0.12em solid var(--box-color); border-radius:0.5em; padding:0.4em; text-align:center;">B</div>
</div>
<div style="flex:1; display:flex; flex-direction:column; gap:0.4em;">
<div style="border:0.12em solid var(--box-color); border-radius:0.5em; padding:0.4em; text-align:center;">C</div>
</div>
</div>

# Layout 1 column input

Add `{.full}` right after the heading text (only used when `layout:` is
absent; with `layout:`, a single-item row is already full width).

```
# BOX D {.full}
...
```

# Layout 1 column output

That one box spans the full width, breaking out of the 2-column flow
(used for wide tables or a summary that should not be split).

<div style="margin:0.3em 0 0;">
<div style="border:0.12em solid var(--box-color); border-radius:0.5em; padding:0.4em; text-align:center;">D (full width)</div>
</div>

For an irregular arrangement, use `layout:` (a matrix of headings) or
`grid:` (`x`/`y`/`w`/`h` per box) — see `../golf_course.md`.
