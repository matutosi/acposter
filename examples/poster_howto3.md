---
title: "build-poster-pdf: irregular layouts"
author: ["Row spans, column spans, and the two ways to write them"]
institute: ["build-poster-pdf"]
type: "学術ポスター"
note: "This page is itself an irregular layout. The grid: header below places every box by coordinate, including the tall box on the right and the wide boxes at the bottom."
grid:
  columns: 3
  boxes:
    - {name: The two notations,   x: 0, y: 0, w: 2}
    - {name: A tall box,          x: 2, y: 0, h: 3}
    - {name: The layout matrix,     x: 0, y: 1}
    - {name: The grid coordinates,  x: 1, y: 1}
    - {name: Which one to use,    x: 0, y: 2, w: 2}
    - {name: What gets checked,   x: 0, y: 3, w: 3}
    - {name: This very page,      x: 0, y: 4, w: 3}
---

# The two notations

Both `layout:` and `grid:` place boxes on a CSS Grid. They differ only in
**how you write the same arrangement**.

- `layout:` — a **matrix of heading names**, written to look like the page.
- `grid:` — an **`x`/`y`/`w`/`h` coordinate per box**, like a dashboard library.

`grid:` wins if you write both.

# A tall box

This box is `h: 3`, so it spans **three rows** — it stays beside the three
boxes on its left instead of being cut into pieces.

A tall box is the usual home for the one thing that needs the most room:
a large results table, an ordination plot, or a long species list.

Because a box grows to fit its contents, a tall box does **not** stretch
its neighbours. The row heights come from whatever is tallest in that row.

- `h: 2` — spans two rows
- `h: 3` — spans three rows (this box)
- `w: 2` — spans two columns (see the boxes below)

# The layout matrix

Repeat a name on several rows to span them.

```
layout:
  - [INTRO, INTRO, TALL]
  - [A, B, TALL]
  - [WIDE, WIDE, TALL]
```

`TALL` appears on all three rows, so it becomes one box three rows high.
`INTRO` and `WIDE` each appear twice on one row, so they are two columns wide.

**The shape of the text is the shape of the page**, which is the point of
this notation.

# The grid coordinates

Give each box a position and a size.

```
grid:
  columns: 3
  boxes:
    - {name: INTRO, x: 0, y: 0, w: 2}
    - {name: TALL,  x: 2, y: 0, h: 3}
    - {name: A,     x: 0, y: 1}
    - {name: B,     x: 1, y: 1}
    - {name: WIDE,  x: 0, y: 2, w: 2}
```

`x`/`y` count from **0** at the top left. `w`/`h` default to `1`.
The same arrangement as the matrix on the left, written once per box.

# Which one to use

Neither is better; they trade off against each other.

| | `layout:` | `grid:` |
|---|---|---|
| Reads like the page | yes | no |
| Spanning box | repeat the name | `w:` / `h:` once |
| Editing one box | retype every affected row | change that box's numbers |
| Many irregular boxes | matrix gets noisy | stays compact |

A rule of thumb: **start with `layout:`**, and switch to `grid:` when the
repeated names start getting in the way.

# What gets checked

A wrong arrangement is caught before the PDF is written, so a broken poster
never reaches the printer quietly.

- **Overlap** — two boxes on the same cell are named in the error.
- **Overflow** — a box whose `x + w` passes `columns` is named.
- **Missing** — a heading in the body but not in `grid:`/`layout:` (or the
  reverse) stops the build.
- **Page count** — the build reports the page count; a poster is always `1`,
  so a `2` means something overflowed the paper.

The last one is a warning rather than an error, because the PDF is still
worth looking at to see *what* overflowed.

# This very page

The header of this file uses `grid:` with `columns: 3`. The box you are
reading is `w: 3` (full width), the tall box on the right is `h: 3`, and
the two notation boxes sit side by side in the middle row.

Compare with `poster_howto.md` (a tour of the features), `poster_howto2.md`
(input and output side by side), and `golf_course.md` (a realistic poster
that uses the `layout:` matrix).
