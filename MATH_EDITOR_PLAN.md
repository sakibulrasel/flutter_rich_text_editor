# Flutter-Native Math Editor Plan

## Goal

Build a Flutter-native math expression feature for a rich text editor that:

- opens a dedicated math dialog
- lets users choose from common math structures and symbols
- supports editing existing equations
- renders the same equation inline or as a block inside the editor
- serializes cleanly to JSON and HTML

This will be similar in workflow to CKEditor + MathType, but it will be your own native Flutter implementation.

## Reality Check

- [ ] Exact parity with MathType is not a realistic MVP.
- [ ] A strong first version is realistic if equations are stored as LaTeX and rendered with a Flutter math renderer.
- [ ] The editor should treat formulas as structured inline/block nodes, not plain text styling.
- [ ] The dialog should be template-driven, not freehand WYSIWYG at first.

## Recommended Technical Direction

- [ ] Use LaTeX as the internal math format.
- [ ] Use a Flutter renderer such as `flutter_math_fork` for preview and display.
- [ ] Support two math node types:
  - `mathInline`
  - `mathBlock`
- [ ] Open a dialog or bottom sheet for insert/edit.
- [ ] Keep the formula editor separate from the main text flow.

## Document Model

- [ ] Add inline node:
  - `mathInline { latex: String }`
- [ ] Add block node:
  - `mathBlock { latex: String, alignment?: center/left/right }`
- [ ] Ensure math nodes can be selected as atomic units.
- [ ] Allow replacing an existing math node with an updated version.

## Editor UX

- [ ] Add toolbar buttons:
  - insert inline math
  - insert block math
- [ ] Tapping a math node should select it.
- [ ] Double tap or edit action should reopen the math dialog with current content.
- [ ] Backspace/delete should remove math node cleanly when selected.
- [ ] Arrow navigation should move across math nodes as atomic content.

## Dialog UX

- [ ] The dialog should contain:
  - formula input area
  - live preview
  - category tabs or sections
  - symbol/template insertion panel
  - insert/update button
- [ ] Provide two editing modes:
  - template-assisted mode
  - direct LaTeX edit mode
- [ ] If time is limited, ship direct LaTeX + template buttons first.

## Suggested Dialog Sections

- [ ] Basic:
  - superscript
  - subscript
  - fraction
  - square root
  - nth root
- [ ] Brackets:
  - parentheses
  - square brackets
  - braces
  - absolute value
- [ ] Operators:
  - plus/minus
  - multiplication
  - division
  - equals
  - not equals
  - approximate
  - plus-minus
- [ ] Greek letters:
  - alpha
  - beta
  - gamma
  - delta
  - theta
  - lambda
  - mu
  - pi
  - sigma
  - omega
- [ ] Calculus:
  - integral
  - double integral
  - derivative forms
  - summation
  - product
  - limit
- [ ] Relations:
  - less than
  - greater than
  - less/greater or equal
  - subset
  - superset
  - element of
- [ ] Linear algebra:
  - matrix 2x2
  - matrix 3x3
  - determinant
  - vector
- [ ] Geometry:
  - angle
  - perpendicular
  - parallel
  - triangle
- [ ] Logic:
  - and
  - or
  - not
  - implies
  - iff

## Template Insertion Strategy

- [ ] Each template button should insert a LaTeX snippet with cursor placeholders.
- [ ] Example templates:
  - fraction: `\\frac{a}{b}`
  - superscript: `x^{n}`
  - subscript: `x_{i}`
  - square root: `\\sqrt{x}`
  - nth root: `\\sqrt[n]{x}`
  - summation: `\\sum_{i=1}^{n}`
  - integral: `\\int_{a}^{b}`
  - matrix: `\\begin{bmatrix} a & b \\\\ c & d \\end{bmatrix}`
- [ ] Support fast replacement of placeholder text after insertion.

## Rendering

- [ ] Render inline math inside paragraphs without breaking line layout more than necessary.
- [ ] Render block math as its own centered block by default.
- [ ] Show a fallback error state for invalid LaTeX.
- [ ] Ensure preview rendering and in-editor rendering use the same renderer.
- [ ] Cache expensive renders if performance becomes an issue.

## Editing Existing Equations

- [ ] When editing an existing math node:
  - open dialog
  - preload current LaTeX
  - show live preview
  - replace node on save
- [ ] Support cancel without changing the original node.
- [ ] Preserve selection around the edited node.

## Validation

- [ ] Validate LaTeX before saving.
- [ ] If invalid, show:
  - parsing error
  - disabled save or explicit warning
- [ ] Decide whether invalid formulas can be saved as raw text.
- [ ] Recommended: disallow invalid math node save in MVP.

## Serialization

### JSON

- [ ] Serialize inline math as:

```json
{
  "type": "mathInline",
  "latex": "\\frac{a}{b}"
}
```

- [ ] Serialize block math as:

```json
{
  "type": "mathBlock",
  "latex": "\\int_a^b x^2 dx",
  "alignment": "center"
}
```

### HTML

- [ ] Export inline math using a stable wrapper, for example:

```html
<span data-node="math-inline" data-latex="\\frac{a}{b}"></span>
```

- [ ] Export block math using a stable wrapper, for example:

```html
<div data-node="math-block" data-latex="\\int_a^b x^2 dx"></div>
```

- [ ] Optionally include a rendered fallback text node for non-editor consumers.
- [ ] Keep HTML import/export centered around your own schema first.

## API Design

- [ ] Add controller methods:
  - `insertInlineMath(String latex)`
  - `insertBlockMath(String latex)`
  - `updateSelectedMath(String latex)`
  - `isMathNodeSelected`
- [ ] Add callbacks if useful:
  - `onMathInserted`
  - `onMathEdited`
  - `onMathValidationError`

## Package Structure Suggestion

- [ ] `lib/src/document/nodes/math_inline_node.dart`
- [ ] `lib/src/document/nodes/math_block_node.dart`
- [ ] `lib/src/math/math_dialog.dart`
- [ ] `lib/src/math/math_palette.dart`
- [ ] `lib/src/math/math_templates.dart`
- [ ] `lib/src/math/math_preview.dart`
- [ ] `lib/src/rendering/math_inline_widget.dart`
- [ ] `lib/src/rendering/math_block_widget.dart`

## MVP Sequence

- [ ] Step 1:
  - inline math node
  - block math node
  - direct LaTeX input dialog
  - live preview
  - render inside editor
- [ ] Step 2:
  - template buttons
  - grouped symbol palette
  - edit existing node
- [ ] Step 3:
  - keyboard placeholder navigation
  - better cursor placement after insertion
  - HTML import/export
- [ ] Step 4:
  - chemistry support if needed
  - matrix builder UI
  - advanced template editing

## Later Chemistry Roadmap

- [ ] Ionic charge notation
  - `Na+`
  - `Ca2+`
  - `SO4^2-`
  - `NH4+`
- [ ] State symbols
  - `(s)`
  - `(l)`
  - `(g)`
  - `(aq)`
- [ ] Reaction conditions
  - heat
  - catalyst
  - pressure
  - light above/below arrows
- [ ] Reversible and equilibrium chemistry arrows
  - dedicated chemistry arrow set beyond generic math arrows
- [ ] Stoichiometric coefficients
  - `2H2 + O2 -> 2H2O`
- [ ] Hydrate and dot notation
  - `CuSO4·5H2O`
- [ ] Organic chemistry shorthand and simple bond notation
- [ ] Bracketed complexes
  - `[Cu(NH3)4]2+`
- [ ] Full reaction auto-formatting
  - reactants
  - products
  - operators
  - state labels
- [ ] Chemistry template palette
  - reaction arrows
  - charges
  - states
  - catalysts
  - equilibrium
- [ ] Stable chemistry import/export rules for JSON and HTML

## Out of Scope for MVP

- [ ] Handwriting recognition
- [ ] Full MathType parity
- [ ] Drag-and-drop formula composition
- [ ] Visual equation tree editor
- [ ] Computer algebra features

## Recommended First Release

- [ ] Insert inline math
- [ ] Insert block math
- [ ] Edit existing equation via dialog
- [ ] LaTeX input with live preview
- [ ] 30-50 high-value templates
- [ ] Common Greek/operator symbols
- [ ] JSON + HTML serialization

## Success Criteria

- [ ] User can insert a fraction, integral, matrix, and superscript without writing full LaTeX manually.
- [ ] User can tap an equation and edit it safely.
- [ ] The equation shown in the editor matches the saved equation.
- [ ] Exported JSON preserves math exactly.
- [ ] Exported HTML preserves enough metadata to rebuild the equation later.
