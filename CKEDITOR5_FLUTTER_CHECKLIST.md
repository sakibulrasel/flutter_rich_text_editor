# CKEditor 5 Flutter Package Checklist

## Feasibility

- [x] Confirm the package is possible.
- [ ] Build it as a Flutter wrapper around a web-based CKEditor 5 instance, not as a native Flutter text engine.
- [ ] Decide target platforms:
  - Flutter Web via `HtmlElementView` / JS interop.
  - Flutter Android/iOS/Desktop via `WebView`.
- [ ] Accept that "all possible features" is only partially under package control:
  - Open-source features can be wrapped directly.
  - Premium features require CKEditor licensing.
  - Some features also require CKEditor Cloud Services or external backends.
  - Some integrations will need JavaScript-side customization beyond Dart API exposure.

## Product Scope

- [ ] Define package goal: "Expose CKEditor 5 in Flutter with configurable plugins, toolbar, events, and premium/cloud integrations."
- [ ] Decide whether to ship:
  - One package with feature flags.
  - A core package plus premium add-on packages.
- [ ] Decide whether to support:
  - Self-hosted CKEditor build.
  - CDN-hosted build.
  - Both.
- [ ] Decide the minimum supported CKEditor 5 version and pin it.
- [ ] Decide the minimum supported Flutter/Dart versions.

## Core Architecture

- [ ] Create a JS bridge layer for editor lifecycle:
  - create editor
  - destroy editor
  - set data
  - get data
  - execute commands
  - read selection state
  - listen to editor events
- [ ] Create a Dart controller API:
  - `initialize`
  - `dispose`
  - `setHtml`
  - `getHtml`
  - `setMarkdown` if enabled
  - `focus`
  - `blur`
  - `executeCommand`
  - `undo` / `redo`
- [ ] Create bidirectional message passing between Dart and JS.
- [ ] Add serialized config passing from Dart to CKEditor 5.
- [ ] Add event streaming for:
  - ready
  - change
  - focus
  - blur
  - error
  - upload progress
  - collaboration state
- [ ] Add watchdog/recovery support.
- [ ] Add read-only mode support.
- [ ] Add placeholder support.
- [ ] Add theme and CSS injection support.
- [ ] Add toolbar configuration support.
- [ ] Add menu bar configuration support.
- [ ] Support multiple editor types where feasible:
  - classic
  - inline
  - balloon
  - balloon block
  - document
  - multi-root if practical

## Packaging Strategy

- [ ] Decide how CKEditor assets are delivered:
  - bundled local assets
  - generated custom build
  - remote CDN
- [ ] Add versioned JS/CSS asset management.
- [ ] Add a build workflow for generating custom CKEditor bundles.
- [ ] Document how plugin selection affects bundle size.
- [ ] Add CSP notes for web.
- [ ] Add offline/self-hosted support documentation.

## Base Editing Features

- [ ] Basic text styles: bold, italic, underline, strikethrough, subscript, superscript.
- [ ] Headings.
- [ ] Paragraphs.
- [ ] Block quote.
- [ ] Code blocks.
- [ ] Text alignment.
- [ ] Font family, size, and color.
- [ ] Highlight.
- [ ] Styles.
- [ ] Horizontal line.
- [ ] Undo/redo.
- [ ] Select all.
- [ ] Remove formatting if included.
- [ ] Case change if included.
- [ ] Text part language.
- [ ] Automatic text transformation.
- [ ] Autoformatting.
- [ ] Slash commands if included.

## Document Structure Features

- [ ] Ordered and unordered lists.
- [ ] To-do lists.
- [ ] Multi-level lists if included.
- [ ] List properties if included.
- [ ] Block indentation.
- [ ] Tables.
- [ ] Table caption.
- [ ] Table styling if included.
- [ ] Table column resizing if included.
- [ ] Layout tables if included.
- [ ] Document title.
- [ ] Table of contents if included.
- [ ] Document outline if included.
- [ ] Bookmarks if included.
- [ ] Footnotes if included.
- [ ] Page break if included.
- [ ] Pagination if included.

## Media and Rich Content

- [ ] Link support.
- [ ] Image insertion.
- [ ] Image captions.
- [ ] Image alt text.
- [ ] Image styles.
- [ ] Image linking.
- [ ] Insert image via URL.
- [ ] Responsive images.
- [ ] Image resize if included.
- [ ] Media embed.
- [ ] HTML embed if included.
- [ ] General HTML support.
- [ ] HTML comment element support.
- [ ] Full page HTML if included.
- [ ] Emoji.
- [ ] Special characters if included.
- [ ] Math and chemical formulas if included.
- [ ] Mermaid diagrams.
- [ ] Templates if included.
- [ ] Merge fields if included.

## Clipboard, Paste, and Import/Export

- [ ] Paste plain text.
- [ ] Paste Markdown.
- [ ] Paste from Office if included.
- [ ] Enhanced paste from Office if included.
- [ ] Paste from Google Docs if included.
- [ ] Markdown output.
- [ ] Source editing.
- [ ] Enhanced source editing if included.
- [ ] Export to PDF if included.
- [ ] Export to Word if included.
- [ ] Export with inline styles if included.
- [ ] Import from Word if included.

## Uploads and File Management

- [ ] Define upload abstraction in Dart:
  - custom upload adapter
  - auth headers
  - progress callbacks
  - cancel support
- [ ] Support image upload.
- [ ] Support custom upload adapter.
- [ ] Support CKBox if included.
- [ ] Support CKFinder if included.
- [ ] Support Uploadcare if included.
- [ ] Add token refresh flow for protected uploads.
- [ ] Add file picker integration across Flutter platforms.

## Productivity Features

- [ ] Find and replace if included.
- [ ] Word and character count if included.
- [ ] Format painter if included.
- [ ] Fullscreen mode.
- [ ] Show blocks.
- [ ] Content minimap.
- [ ] Mentions.
- [ ] Restricted editing if included.
- [ ] Comments-only mode if included.

## Collaboration Features

- [ ] Decide whether collaboration is in scope for v1.
- [ ] Add user identity mapping from Flutter to CKEditor.
- [ ] Add comments support if included.
- [ ] Add track changes support if included.
- [ ] Add revision history support if included.
- [ ] Add real-time collaboration support if included.
- [ ] Add annotations display mode configuration.
- [ ] Add comments outside editor support if needed.
- [ ] Add persistence strategy for comments/suggestions/revisions.
- [ ] Validate Cloud Services requirements and credentials flow.

## AI Features

- [ ] Decide whether CKEditor AI is in scope.
- [ ] Support AI chat if included.
- [ ] Support quick actions if included.
- [ ] Support review and translate features if included.
- [ ] Support MCP integration if included.
- [ ] Define where AI credentials live and how they are secured.
- [ ] Document that AI features may require server-side setup and vendor-specific policies.

## Flutter API Design

- [ ] Create a clean `RichTextEditor` widget API.
- [ ] Create a controller for imperative actions.
- [ ] Expose strongly typed configuration objects instead of raw maps where reasonable.
- [ ] Still allow escape hatches for raw CKEditor config JSON.
- [ ] Expose toolbar presets plus fully custom toolbar definitions.
- [ ] Expose plugin toggles and capability checks.
- [ ] Expose callbacks for:
  - content change
  - editor ready
  - focus/blur
  - upload start/success/failure
  - command execution
  - collaboration changes
- [ ] Support form integration and validation.
- [ ] Support initial value and controlled/uncontrolled modes.

## Platform-Specific Work

- [ ] Flutter Web:
  - JS interop
  - asset loading
  - CSP compatibility
  - sizing/focus fixes
- [ ] Android:
  - WebView config
  - file chooser
  - keyboard/focus handling
  - upload permissions if needed
- [ ] iOS:
  - WKWebView config
  - file picker bridge
  - keyboard/focus handling
- [ ] macOS/Windows/Linux:
  - desktop WebView behavior
  - drag-and-drop
  - clipboard integration

## Security and Compliance

- [ ] Handle license key configuration.
- [ ] Support GPL mode where appropriate.
- [ ] Clearly separate open-source vs premium features in docs.
- [ ] Do not hardcode production license keys into distributed client code without understanding exposure risk.
- [ ] Document approved-host or domain restrictions where relevant.
- [ ] Sanitize or validate custom HTML config pathways.
- [ ] Review content security implications of embeds and HTML support.

## Testing

- [ ] Unit test Dart controller behavior.
- [ ] Integration test create/destroy lifecycle.
- [ ] Integration test set/get data.
- [ ] Integration test toolbar command execution.
- [ ] Integration test image upload flow.
- [ ] Integration test read-only mode.
- [ ] Integration test focus handling.
- [ ] Integration test web and at least one mobile platform.
- [ ] Add regression tests for JS bridge protocol changes.
- [ ] Add manual test matrix for premium/cloud features.

## Documentation

- [ ] Write quick-start docs for Flutter Web.
- [ ] Write quick-start docs for Android/iOS with WebView.
- [ ] Document self-hosted setup.
- [ ] Document CDN setup.
- [ ] Document custom CKEditor build generation.
- [ ] Document feature compatibility matrix.
- [ ] Document premium feature prerequisites.
- [ ] Document Cloud Services prerequisites.
- [ ] Document license and pricing caveats.
- [ ] Document known limitations per platform.
- [ ] Add example apps:
  - minimal editor
  - feature-rich editor
  - upload demo
  - collaboration demo
  - AI demo if supported

## Release Plan

- [ ] v0: Prove embedding, lifecycle, set/get HTML, toolbar, and basic plugins.
- [ ] v1: Stable Flutter API, uploads, tables, lists, images, source editing, markdown, fullscreen.
- [ ] v2: Premium feature adapters, collaboration, export/import, advanced embeds.
- [ ] v3: AI integrations, multi-root, advanced customization, enterprise hardening.

## Recommended First Milestone

- [ ] Start with:
  - classic editor
  - self-hosted custom build
  - HTML set/get
  - toolbar config
  - headings, bold/italic, lists, link, table, image, code block
  - custom image upload adapter
  - read-only mode
  - watchdog
  - Flutter Web + Android support
- [ ] Defer initially:
  - real-time collaboration
  - comments/track changes
  - export/import services
  - AI features
  - every premium plugin

## Reality Check

- [ ] Treat "support everything in CKEditor 5 docs" as a long-term roadmap, not an MVP.
- [ ] Expect some features to be wrappers around licensed JS plugins and CKEditor services, not pure Dart implementations.
- [ ] Expect ongoing maintenance whenever CKEditor 5 plugin APIs, asset packaging, or licensing requirements change.

## Sources

- CKEditor 5 docs index: https://ckeditor.com/docs/ckeditor5/latest/index.html
- License key and activation: https://ckeditor.com/docs/ckeditor5/latest/getting-started/licensing/license-key-and-activation.html
