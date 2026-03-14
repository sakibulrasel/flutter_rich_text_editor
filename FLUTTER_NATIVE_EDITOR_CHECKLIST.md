# Flutter-Native Rich Text Editor Checklist

## Scope Decision

- [ ] Accept that this will be a Flutter-native editor, not CKEditor 5 compatibility.
- [ ] Define the document model first before building UI.
- [ ] Treat advanced collaboration, Office-grade paste fidelity, and CKEditor-style plugin parity as post-MVP or out of scope.
- [ ] Decide the serialization format:
  - custom JSON document model
  - HTML import/export
  - Markdown import/export
  - Delta-style ops
- [ ] Pick one canonical internal model and make all other formats adapters.

## MVP Goal

- [ ] Deliver a stable editor with:
  - paragraphs
  - headings
  - bold / italic / underline / strikethrough
  - ordered / unordered lists
  - links
  - block quote
  - code block
  - inline code
  - images
  - undo / redo
  - selection handling
  - copy / paste
  - JSON save/load

## Core Architecture

- [ ] Create a document tree model.
- [ ] Define block nodes:
  - paragraph
  - heading
  - quote
  - code block
  - list
  - list item
  - image
  - table later
- [ ] Define inline spans/marks:
  - bold
  - italic
  - underline
  - strikethrough
  - link
  - inline code
- [ ] Define position and range types.
- [ ] Define selection model.
- [ ] Define editor transaction model.
- [ ] Define command system.
- [ ] Define normalization rules for invalid document states.

## Rendering Layer

- [ ] Build a custom editor surface widget.
- [ ] Render blocks from the document model.
- [ ] Render inline spans with styles.
- [ ] Support caret drawing and selection painting.
- [ ] Support placeholder rendering.
- [ ] Support read-only mode.
- [ ] Support focus handling.
- [ ] Support scrolling to caret.

## Editing Engine

- [ ] Insert text at selection.
- [ ] Delete backward / forward.
- [ ] Replace selected range.
- [ ] Split paragraph on enter.
- [ ] Merge blocks on backspace/delete boundaries.
- [ ] Toggle inline marks on selected text.
- [ ] Toggle block types.
- [ ] Support soft line break vs paragraph break.
- [ ] Preserve selection after edits.
- [ ] Normalize document after each transaction.

## Selection and Input

- [ ] Handle tap-to-place-caret.
- [ ] Handle drag selection.
- [ ] Handle double-tap word selection.
- [ ] Handle long-press selection on mobile.
- [ ] Integrate with Flutter `TextInputClient` or equivalent input channel.
- [ ] Support hardware keyboard input.
- [ ] Support IME/composing text.
- [ ] Support arrow-key navigation.
- [ ] Support shift-selection expansion.
- [ ] Support home/end movement where practical.

## Commands and Toolbar

- [ ] Define command API:
  - bold
  - italic
  - underline
  - strikethrough
  - heading
  - list
  - quote
  - code block
  - link
  - undo
  - redo
- [ ] Expose toolbar state from current selection.
- [ ] Build default toolbar widgets.
- [ ] Allow custom toolbar integration.
- [ ] Allow keyboard shortcuts.

## Undo/Redo

- [ ] Add history stack.
- [ ] Group typing operations into transactions.
- [ ] Support undo/redo for formatting changes.
- [ ] Restore selection with history operations.

## Clipboard and Paste

- [ ] Support copy selected content.
- [ ] Support cut.
- [ ] Support plain-text paste first.
- [ ] Add HTML paste parser later.
- [ ] Add Markdown paste support later.
- [ ] Sanitize pasted HTML before converting.

## Serialization

- [ ] Implement JSON serialize/deserialize.
- [ ] Implement HTML export.
- [ ] Implement HTML import.
- [ ] Implement Markdown export if needed.
- [ ] Implement Markdown import if needed.
- [ ] Version serialized document format.

## Images and Embeds

- [ ] Add image block node.
- [ ] Support image insertion from file or URL.
- [ ] Support image sizing/alignment.
- [ ] Add async upload interface.
- [ ] Show upload progress/loading state.
- [ ] Decide whether embeds are in scope:
  - video
  - iframe
  - custom widgets

## Tables

- [ ] Decide whether tables are MVP or phase 2.
- [ ] If included, define table model:
  - table
  - row
  - cell
- [ ] Support cell selection.
- [ ] Support row/column insert/delete.
- [ ] Support cell merge only if truly needed.

## API Design

- [ ] Create `RichTextEditor` widget.
- [ ] Create `RichTextEditorController`.
- [ ] Expose:
  - document
  - selection
  - commands
  - focus
  - serialization helpers
- [ ] Expose callbacks:
  - `onChanged`
  - `onSelectionChanged`
  - `onFocusChanged`
  - `onSubmitted` if relevant
- [ ] Support form-field integration.

## Platform Support

- [ ] Validate Flutter Android behavior.
- [ ] Validate Flutter iOS behavior.
- [ ] Validate Flutter Web behavior.
- [ ] Validate Flutter desktop behavior.
- [ ] Test hardware keyboard behavior on desktop/web.
- [ ] Test IME on mobile.

## Testing

- [ ] Unit test document model.
- [ ] Unit test normalization rules.
- [ ] Unit test command behavior.
- [ ] Unit test undo/redo.
- [ ] Widget test rendering of formatted spans.
- [ ] Widget test selection and caret behavior where feasible.
- [ ] Integration test typing, formatting, paste, and serialization.
- [ ] Add golden tests for editor rendering.

## Documentation

- [ ] Write architecture overview.
- [ ] Document the document model.
- [ ] Document supported formatting/features.
- [ ] Document serialization format.
- [ ] Document known limitations.
- [ ] Add example app:
  - basic editor
  - toolbar editor
  - form integration
  - image upload demo

## Release Plan

- [ ] Phase 1:
  - document model
  - rendering
  - typing
  - basic formatting
  - undo/redo
  - JSON persistence
- [ ] Phase 2:
  - links
  - images
  - block types
  - HTML import/export
- [ ] Phase 3:
  - tables
  - advanced paste
  - Markdown
  - desktop/web shortcuts polish
- [ ] Phase 4:
  - embeds
  - collaborative model exploration
  - plugin/extensibility system

## Recommended Starting Point

- [ ] First implement:
  - paragraph node
  - text span marks
  - selection model
  - text insertion/deletion
  - bold/italic/underline
  - headings
  - lists
  - undo/redo
  - JSON save/load
- [ ] Defer initially:
  - tables
  - complex paste
  - collaboration
  - comments
  - track changes
  - Office import fidelity
  - AI features

## Reality Check

- [ ] Native Flutter gives you full control, but you are building an editor engine.
- [ ] The hardest parts are selection, IME/composition, undo/redo, and paste normalization.
- [ ] A strong MVP is achievable; CKEditor-level breadth is a multi-stage project.
