# Math Progress Checklist

## Implemented

- [x] Inline math insertion in text blocks
- [x] Standalone block math insertion
- [x] Render inline math inside the editor
- [x] Render block math inside the editor
- [x] Tap existing inline math to reopen the math dialog
- [x] Tap existing block math to reopen the math dialog
- [x] JSON serialization for math content
- [x] HTML serialization for math content
- [x] Math dialog supports `Inline` and `Standalone`
- [x] Visual composer extracted into a separate file
  - [x] [lib/src/math/math_visual_composers.dart](/Users/sakibulhaque/Desktop/Project/dart_package/rich_text_editor/lib/src/math/math_visual_composers.dart)

## Implemented Templates

- [x] Fraction visual composer
- [x] Power visual composer
- [x] Subscript visual composer
- [x] Square root visual composer
- [x] Nth root visual composer
- [x] Integral visual composer
- [x] Summation visual composer
- [x] Matrix 2x2 visual composer
- [x] Symbol palette
- [x] Plain-expression category

## Recursive Editing

- [x] Fraction numerator and denominator reopen recursive editor
- [x] Root radicand and index reopen recursive editor
- [x] Integral slots reopen recursive editor
- [x] Nested formula insertion inside recursive slots
- [x] Full formula preview inside recursive dialogs
- [x] Existing supported formulas reopen their matching visual editor

## Expression Editor

- [x] Visual token rendering for expressions
- [x] Caret positions between tokens
- [x] Insert at caret instead of only append-after-selected
- [x] Arrow-left and arrow-right move the formula caret
- [x] Backspace at formula caret
- [x] Delete at formula caret
- [x] Edit selected token
- [x] Edit whole expression
- [x] Add plain expression text
- [x] Character-level plain text tokenization
- [x] Local auto-conversion suggestion chips

## Typed Upgrades

- [x] `a / b` -> fraction
- [x] `ab / cd` -> fraction
- [x] `x ^ 2` -> power
- [x] `x ^ 10` -> power
- [x] `H _ 2` -> subscript
- [x] `CO _ 2` -> subscript-style grouped base
- [x] `sqrtx` -> square root
- [x] `sqrt(x)` -> square root
- [x] `root(3,x)` -> nth root
- [x] `->` -> reaction arrow
- [x] `<->` -> reversible/equilibrium-style arrow
- [x] `H2O` -> chemistry-aware subscripts
- [x] `C6H12O6` -> chemistry-aware subscripts
- [x] `Ca(OH)2` -> grouped chemistry subscript conversion

## Still Missing

- [ ] True caret editing inside a single text token without token boundaries
- [ ] Full MathType-style freeform visual editing
- [ ] Automatic visual conversion for more patterns without relying on tokenized text
- [ ] Smarter matrix editing beyond 2x2 MVP
- [ ] Better summation/integral slot keyboard UX
- [ ] Copy/paste normalization for math expressions
- [ ] Undo/redo scoped specifically to recursive math editing actions
- [ ] Selection drag behavior inside recursive formula editor
- [ ] Inline conversion bubble at caret instead of only action/suggestion area
- [ ] Richer chemistry features
  - [ ] ionic charges
  - [ ] state symbols
  - [ ] hydrate notation
  - [ ] reaction conditions
  - [ ] complexes

## Not Planned for MVP

- [ ] Handwriting recognition
- [ ] Full MathType parity
- [ ] Computer algebra features
- [ ] Advanced organic structure drawing
