# Missing Features Compared To `quill_html_editor`

Source checked: [`quill_html_editor` on pub.dev](https://pub.dev/packages/quill_html_editor/versions) and its published feature list on March 15, 2026.

This package already has some strengths that `quill_html_editor` does not focus on as much, especially:

- Flutter-native document model
- inline and block math editing
- JSON serialization
- HTML export
- image nodes and floating image work

But compared to `quill_html_editor`, the following gaps are still present.

## P0: Core Product Gaps

- [ ] Add full HTML import/edit support.
  Right now the package can export HTML, but it cannot load arbitrary HTML back into the editor as editable content.

- [ ] Add a real WYSIWYG HTML editing pipeline.
  `quill_html_editor` is built around Quill JS and edits HTML-oriented content directly. This package still behaves more like a custom document editor with HTML export rather than a full HTML editor.

- [ ] Add clipboard-rich paste support.
  `quill_html_editor` supports copy-pasting rich content from webpages/files. This package currently lacks robust paste handling for formatted text, links, lists, images, and embedded structures.

- [ ] Add API methods to set/get content in multiple formats.
  Missing parity APIs include easy `setHtml`, `getHtml`, `insertHtml`, and content-loading flows designed for app integration.

## P1: Data Model / Interop Gaps

- [ ] Add Delta format import/export.
  `quill_html_editor` supports `setDelta` and `getDelta`. This package currently uses its own JSON document model only.

- [ ] Add stable conversion layers between document JSON, HTML, and Delta.
  This is needed for migrations, interoperability, server persistence, and editor replacement strategies.

- [ ] Add a more complete selection and editing command API.
  A Quill-style controller exposes richer programmatic editing than this package currently provides.

## P1: Formatting Gaps

- [ ] Add text color and background highlight.
- [ ] Add font family support.
- [ ] Add font size support.
- [ ] Add text alignment controls.
- [ ] Add strikethrough.
- [ ] Add blockquote support.
- [ ] Add code / code block support.
- [ ] Add horizontal rule or divider blocks.

These are common rich text features and are expected in editors positioned against Quill-based packages.

## P1: Embed / Content Block Gaps

- [ ] Add video embed support.
  `quill_html_editor` explicitly supports embedded videos; this package currently does not.

- [ ] Add table editing support.
  This is one of the largest missing content features versus Quill-based editors.

- [ ] Add richer image handling.
  Current image support exists, but there is still no clear upload pipeline, resize handles UX parity, captions, alt-text workflow polish, or paste/drop insertion flow comparable to mature editors.

## P2: Toolbar / Customization Gaps

- [ ] Add detached toolbar support as a first-class API.
  `quill_html_editor` allows placing the toolbar separately from the editor. This package currently keeps toolbar behavior coupled to the editor widget.

- [ ] Add configurable toolbar item lists.
- [ ] Add custom toolbar button injection.
- [ ] Add custom style registration for new marks/nodes.
- [ ] Add customizable color palettes and font-size lists.

## P2: Platform / Integration Gaps

- [ ] Add explicit web-platform support and test coverage.
  `quill_html_editor` is positioned for Android, iOS, and Web. This package has not yet demonstrated equivalent web editor maturity.

- [ ] Add more complete read-only rendering widgets.
  Exporting HTML is useful, but apps often need a native read-only renderer for the same document model.

- [ ] Add document change batching and editor lifecycle APIs.
  Needed for autosave, collaboration hooks, analytics, and large-document performance tuning.

## P2: UX / Editing Workflow Gaps

- [ ] Add drag/drop and paste workflows for media.
- [ ] Add better undo/redo batching.
  Undo/redo exists, but it is still fairly low-level and not grouped like a mature editor.

- [ ] Add keyboard shortcut coverage for desktop/web.
- [ ] Add selection toolbar behavior closer to established editors.
- [ ] Add placeholder and empty-state customization across all node types.

## Suggested Build Order

- [ ] 1. HTML import + `setHtml` / `getHtml`
- [ ] 2. Rich paste support
- [ ] 3. Delta import/export
- [ ] 4. Detached/customizable toolbar API
- [ ] 5. Text color, font, alignment, strikethrough
- [ ] 6. Video embeds
- [ ] 7. Table support
- [ ] 8. Web-platform hardening and tests

## Important Note

Do not copy Quill blindly.

This package has a different opportunity:

- native Flutter editing
- stronger math support
- custom document-node architecture

So the goal should be selective parity where it improves product value, not full Quill feature cloning.
