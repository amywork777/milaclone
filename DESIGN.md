---
name: Pinboard
description: A personal visual notebook with quiet structure.
colors:
  primary: "#79576e"
  canvas: "#f4f3f0"
  rail: "#faf9f7"
  chrome: "#fdfcfa"
  card: "#ffffff"
  border: "#e3dfdc"
  card-border: "#dfdadd"
  ink: "#302e32"
  ink-soft: "#6f6870"
  ink-faint: "#817982"
  active-fill: "#eae4e9"
  active-ink: "#62475b"
  hover-fill: "#eee9ed"
  column-fill: "#eae7e387"
  tools: "#493e47"
  text-selection: "#ead4e3"
  slate: "#76717a"
  gray: "#bcb8bd"
  teal: "#79a59c"
  green: "#8ca884"
  brown: "#ad9079"
  yellow: "#e2c671"
  orange: "#dca376"
  red: "#c87b7d"
  pink: "#c78fa8"
  purple: "#a091b5"
  blue: "#91adca"
  indigo: "#8c94bc"
typography:
  headline:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "27px"
    fontWeight: 550
    letterSpacing: "-0.6px"
  brand:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "20px"
    fontWeight: 600
    letterSpacing: "-0.6px"
  dialog-title:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "18px"
    fontWeight: 550
  card-title:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "14px"
    fontWeight: 550
  body:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: '"Helvetica Neue", Helvetica, Arial, sans-serif'
    fontSize: "11px"
    fontWeight: 400
rounded:
  compact: "5px"
  card: "6px"
  dialog: "9px"
spacing:
  compact: "7px"
  control: "9px"
  pane: "12px"
  stack: "14px"
  dialog: "20px"
  arrange: "25px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.card}"
    rounded: "{rounded.compact}"
    padding: "8px 13px"
  button-organize:
    backgroundColor: "{colors.chrome}"
    rounded: "{rounded.compact}"
    padding: "7px 9px"
  input:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.compact}"
    padding: "11px"
  navigation-current:
    backgroundColor: "{colors.active-fill}"
    textColor: "{colors.active-ink}"
    rounded: "{rounded.card}"
    padding: "8px"
  note-card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.card}"
    padding: "14px 16px"
  column:
    backgroundColor: "{colors.column-fill}"
    rounded: "{rounded.compact}"
    padding: "14px 12px"
---

# Design System: Pinboard

## Overview

**Creative North Star: "A personal visual notebook"**

Pinboard is a light personal visual notebook: real notes, images, links, tasks, and nested boards on a movable canvas. Quiet, compact controls and a persistent board tree give collected material a home without turning the canvas into a dashboard.

The established tool route is operate mode: square structural panes, gently rounded controls, sans typography, and motion at interaction boundaries. The project-specific light Milanote-like direction overrides the copied kit’s dark default. The single loop mark supplies the handmade detail; Tidy up is the signature interaction.

**Key Characteristics:**
- Warm neutral canvas and white material cards.
- Quiet plum selection and keyboard focus.
- Persistent orientation through a board tree, breadcrumbs, and global search.
- Columns provide structure while the canvas remains free to arrange.

This is a refresh of the implementation's established direction, not a new visual proposal. Precedence remains this document, then Taste's signature and tool route, then Impeccable defaults. The MIT-licensed `ellshep/milaclone` foundation supplies the native canvas, drag/resize model, nested boards, columns, card types, mobile canvas, and quick notes. The Pinboard adaptation supplies the light/plum treatment, loop identity, persistent sidebar, global search, Tidy up, recovery controls, and backup affordances. Source code and local notebook data are separate; the current implementation is local, and hosting remains undecided.

The rendered source of truth is the cascade in `public/index.html`: copied `public/kit/tokens/tool.css`, upstream `public/style.css`, then `public/personal.css`. The copied kit is provenance, not the final rendered palette. Its dark surface tokens and decorative font names must not be mistaken for active application roles. The final `--sans` and `--serif` both resolve to the sans stack above; upstream font downloads do not establish a serif role.

## Colors

The palette is warm paper and muted plum. The frontmatter records the implemented values; user-selected card colors are content metadata rather than additional brand accents.

### Primary

- **Quiet plum** (`primary`): selection outlines, focus, text caret, confirmed actions, and the loop mark.
- **Plum wash** (`active-fill`, `active-ink`, `hover-fill`): current board and interactive states.
- **Text selection** (`text-selection`): the browser selection highlight.

### Neutral

- **Warm canvas** (`canvas`): the work area beneath the subtle dot grid.
- **Paper chrome** (`rail`, `chrome`): structural sidebar, tool rail, top bar, and footer.
- **White material** (`card`): notes, images, links, tasks, and dialogs.
- **Soft group** (`column-fill`): translucent column backing; it holds cards together without becoming a raised panel.
- **Ink** (`ink`, `ink-soft`, `ink-faint`): main text, secondary labels, and placeholders.
- **Quiet rules** (`border`, `card-border`): structural dividers and card edges.
- **Dark tools** (`tools`): contextual card controls and toast backgrounds.

The `slate` through `indigo` tokens are the muted inherited card/icon color choices. They classify the user's material; they do not redefine primary action styling.

**The State Accent Rule.** Plum signals focus, selection, or an action; broad structural surfaces remain neutral.

## Typography

One system sans stack carries the interface and content. This is intentionally familiar and compact, with no decorative display or monospace role. The font is local-system dependent; Helvetica Neue falls back to Helvetica or Arial.

- **Headline**: editable board title; it reduces to 23px in the intermediate desktop range.
- **Brand**: lowercase wordmark beside the single loop mark.
- **Dialog title**: restrained heading for search, board creation, and help.
- **Card title**: notes, task cards, and board labels; column headings use 13px at the same weight.
- **Body**: readable card copy and task text. Card text uses the frontmatter line height.
- **Label**: final toolbar, footer, save-state, and shortcut text. Sidebar board buttons and breadcrumbs use 12px.

The recorded 550 weights are the CSS values; actual weight rendering depends on the installed font. Do not introduce a second family merely because upstream font resources remain linked.

## Layout

The application fills the viewport. Structural panes meet at straight edges; rounded cards live inside the canvas rather than wrapping the whole application.

On desktop, the board sidebar is 210px wide. A 52px top bar and 106px board heading sit above a 68px tool rail. The canvas begins at left 278px and top 158px, with a 31px footer below. The canvas dot grid repeats every 18px. Columns use the frontmatter padding and a 14px card gap. Nested board entries indent by 13px per level, capped at six levels.

Between 701px and 1000px, the sidebar narrows to 180px and the canvas starts at 248px; the heading receives 20px horizontal padding. At 700px and below, desktop chrome disappears. The upstream mobile canvas occupies the available width above a 70px bottom area. It remains a pannable spatial canvas, so cards can extend beyond the screen. Boards open in a 240px drawer with a dismissing veil. The bottom navigation retains Your boards, Quick notes, and add-card entry points. Mobile sheets cap at 70dvh, dialogs at 75dvh.

Tidy up lays out unlocked top-level objects in rows with 25px gaps. A column moves as a unit with its children; locked objects keep their positions. The arrangement starts below any locked top-level objects. It changes spatial layout and camera position rather than replacing the canvas with a permanent grid.

## Elevation & Depth

Material cards have a small soft shadow, while structural panes rely on background tones and fine dividers. Columns stay flat. Contextual controls sit above the selected card; dialogs receive a stronger shadow and a translucent veil. The exact shadow vocabulary lives in `.impeccable/design.json`.

Selection uses a plum outline (2px, offset 2px; 1px offset on mobile), preserving the card's material surface. It does not depend on shadow alone. Controls receive a visible plum focus outline (2px, offset 3px); active text editing uses an underline treatment.

## Shapes

Use the frontmatter's compact and card corner values for normal controls and material. Dialogs are slightly softer. Column markers are small circular dots (6px); board icon tiles are square with rounded corners (56px). The app's single loop brand mark is the expressive exception to the otherwise quiet geometry.

## Components

- **Board navigation:** persistent nested list, muted current-board fill, ellipsized labels, and `aria-current`. A mobile drawer reuses this tree.
- **Search:** Find anything opens a focused search dialog; Command/Ctrl K is the shortcut. Results show the board or card's context. Choosing a card navigates to it, selects it, and centers it. Dialogs trap tab focus, close on Escape or outside click, and return focus to the previous control.
- **Organization controls:** Undo, Redo, Tidy up, and Fit board sit beside the board title. Tidy is the sole signature arrangement action. Disabled history controls are visibly dimmed. Server-session undo availability is reflected in their state.
- **Notes and task cards:** compact titles, readable text, small corners, light material shadows. Double-click or Enter on a focused card enters editing or opens a board. Task checkboxes use the accent when checked; completed text is subdued and struck through.
- **Images and links:** images are edge-to-edge card material with gently curved corners. Links keep a thin identifying color bar and readable destination information.
- **Columns:** translucent flat backing, small color marker, title, and vertical stack. Drag into a column or use the selected card's move select control.
- **Contextual card tools:** dark compact toolbar over the selected card, with inherited card actions and the column destination selector.
- **Dialogs:** white surface, quiet input border, ordinary secondary buttons, plum confirmation button. Avoid adding decorative layers.
- **Recovery and status:** sidebar export backup and saved-state text, Undo/Redo, and concise toasts. These labels describe the local service; they are not evidence of remote hosting.

Button backgrounds transition in 120ms. Tidy positions transition in 320ms with `cubic-bezier(.2,.8,.2,1)` only when reduced motion is not requested. Reduced motion disables transitions, animations, and smooth scrolling globally. Do not add continuous ornamental animation.

## Do's and Don'ts

### Do

- Do retain the light canvas and recognizable upstream editing tools.
- Do use the board tree and grouped columns to provide organization.
- Do keep the loop mark as the single handmade brand detail.
- Do expose named controls, visible focus, and keyboard alternatives to dragging.
- Do preserve reduced-motion behavior when adding interactions.
- Do distinguish source-code publication from notebook storage in product language.

### Don't

- Don't replace the personal palette with the copied kit’s dark defaults.
- Don't introduce serif display type, ornamental motion, or dashboard decoration.
- Don't turn every collected card into a saturated accent surface.
- Don't claim the mobile canvas reflows into a vertical list.
- Don't imply that a public fork makes private notebook data public.

Recorded from the final CSS cascade, organization code, and `.impeccable/review/desktop.png` and `mobile.png`. The screenshots establish visual composition; source inspection establishes the documented interaction rules.
