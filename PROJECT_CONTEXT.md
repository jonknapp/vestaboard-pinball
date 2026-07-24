# Project Context

## What This Is

A static HTML tool for building and previewing messages for a **Vestaboard Note** — a small split-flap display board with a 3-row × 15-column grid. The primary use case is a **pinball arcade scoreboard**: rotating through machine names and showing top scores on the physical board.

The app is deployed as a static site on [fly.io](https://fly.io) (`vestaboard-pinball`) and served from the `public/` folder. It is tested locally with `./serve.sh`.

---

## Vestaboard API Overview

Official documentation: https://docs.vestaboard.com/docs/read-write-api/introduction

### Board Dimensions

| Device | Rows | Columns |
|---|---|---|
| Vestaboard Note | 3 | 15 |
| Vestaboard Flagship | 6 | 22 |

This project targets the **Vestaboard Note** (3×15).

### Character Codes

Every cell on the board is represented by an integer code 0–71. Not all integers in that range are valid — there are gaps.

| Code | Character | Notes |
|---|---|---|
| 0 | Blank | Black on black |
| 1–26 | A–Z | Uppercase only |
| 27–36 | 1–9, 0 | Digits |
| 37 | ! | |
| 38 | @ | |
| 39 | # | |
| 40 | $ | |
| 41 | ( | |
| 42 | ) | |
| 44 | - | Hyphen (43 is invalid) |
| 46 | + | Plus (45 is invalid) |
| 47 | & | |
| 48 | = | |
| 49 | ; | |
| 50 | : | |
| 52 | ' | Single quote (51 is invalid) |
| 53 | " | Double quote |
| 54 | % | |
| 55 | , | |
| 56 | . | |
| 59 | / | Slash (57, 58 are invalid) |
| 60 | ? | |
| 62 | ° / ♥ | Degree on Flagship; Heart on Note (61 is invalid) |
| 63 | Red | Color chip |
| 64 | Orange | Color chip |
| 65 | Yellow | Color chip |
| 66 | Green | Color chip |
| 67 | Blue | Color chip |
| 68 | Violet | Color chip |
| 69 | White | Color chip |
| 70 | Black | Color chip |
| 71 | Filled | Color chip |

**Invalid codes** (gaps): 43, 45, 51, 57, 58, 61

Full reference: https://docs.vestaboard.com/docs/characterCodes

### Cloud API

Base URL: `https://cloud.vestaboard.com/`

Authentication: pass your token in the `X-Vestaboard-Token` request header.

**Send a message (POST /)**

```json
{
  "characters": [
    [0, 0, 8, 5, 12, 12, 15, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  ]
}
```

Each inner array is one row. The board accepts text (`{"text": "Hello"}`) or a raw character-code array. Rate limit: 1 message per 15 seconds.

**Read current message (GET /)**

Returns `{ "currentMessage": { "layout": "[[...]]", "id": "..." } }`.

Full endpoint reference: https://docs.vestaboard.com/docs/read-write-api/endpoints

### Local API

For use on a local network without cloud routing. The board must be paired and online to receive firmware first.

Base URL: `http://<board-ip>:7000/`

Send a message with a raw array of arrays as the POST body (no wrapper object).

Full local API reference: https://docs.vestaboard.com/docs/local-api/introduction

---

## Application Architecture

Single static HTML file: `public/index.html`. No build step, no dependencies. All state lives in the URL as query parameters so the page is fully shareable and survives refresh.

### Modes

The app has two modes, selectable via a dropdown at the top of the page.

#### Enter Score (editor mode)

A manual cell-by-cell editor for the 3×15 board. The active cell is highlighted; arrow keys navigate and change values. Character codes can also be typed directly (1–2 digits, auto-committed).

- Up/down arrows increment or decrement the code of the selected cell (wraps 0↔71)
- Left/right arrows move the cursor across cells, wrapping across row boundaries and looping end-to-start
- Shift+up/down jumps ±10
- Cells with invalid codes (gaps in the Vestaboard code table) are shown with a red hatch pattern
- URL param: `?mode=editor&b=<comma-separated 45 codes>`

#### Score Display (display mode)

Automatically composes and previews a scoreboard layout on the 3×15 board:

- **Row 1** — current pinball machine name, centered
- **Row 2** — first player entry that has a name, formatted as `NAME   SCORE` to fill 15 columns
- **Row 3** — second player entry with a name, same format; blank if fewer than two named entries

If a player entry has no name it is skipped entirely, so a single named entry always appears on row 2 regardless of whether it is player 1 or player 2.

**Score table** — a collapsable table below the game names list with one row per game. Columns: Game | #1 Name | #1 Score | #2 Name | #2 Score. All name and score cells are inline-editable. New games are pre-filled with default values; edits to existing rows are preserved when the game list changes. The currently displayed game is highlighted in the table.

The machine name cycles through the list every 5 seconds. Editing the game names list rebuilds the table and restarts rotation from the first game.

URL params: `?mode=display&games=<url-encoded newline-separated list>&scores=<url-encoded JSON array of [game, p1n, p1s, p2n, p2s] tuples>`

### Split-Flap Animation

When a cell's value changes, it plays a CSS animation simulating the physical flap mechanism — cycling through intermediate character codes along the shortest path on the valid-code wheel before landing on the target value. Invalid codes (not on the wheel) snap instantly with no animation.

Each cell animates independently via a `setTimeout` chain. If a new change arrives while a cell is still animating, it cancels immediately and snaps to the new target to prevent UI hangs. Arrow key repeats are throttled to 60ms to stay within the animation budget.

### Debug Panel

Both modes show a live debug panel at the bottom of the page with the current board state formatted as:

- **Cloud API body** — `{ "characters": [[...], [...], [...]] }` ready to POST to `https://cloud.vestaboard.com/`
- **Local API body** — raw `[[...], [...], [...]]` array ready to POST to `http://<board-ip>:7000/local-message`

The panel updates on every change.

---

## Deployment

- Hosted on [fly.io](https://fly.io), app name: `vestaboard-pinball`, region: `iad`
- Auto-deploys on push to GitHub via `.github/` workflows
- Served from `public/` on port 80 inside a Docker container (see `Dockerfile` and `serve.sh`)
- Local dev: `./serve.sh` — mounts `nginx.dev.conf` which disables HTML caching so changes are picked up immediately without rebuilding the image
