# rich-text-editor-renderer

Browser renderer for `rich_text_editor` JSON documents.

## Install

```bash
npm install rich-text-editor-renderer
```

## Usage

```js
import { renderRichTextDocument } from 'rich-text-editor-renderer';

renderRichTextDocument({
  element: document.getElementById('viewer'),
  document: savedJsonFromDatabase,
});
```

## Auto Mount

If the page includes the global bundle, the renderer can auto-mount saved JSON from HTML without manual per-document JS calls.

```html
<div class="rte-viewer" data-rich-text-json='{"version":1,"nodes":[...]}'></div>
<script src="https://cdn.jsdelivr.net/npm/rich-text-editor-renderer/dist/index.global.js"></script>
```

The global bundle auto-renders `.rte-viewer[data-rich-text-json]` on page load.

It also supports a custom element:

```html
<rich-text-editor-viewer data-rich-text-json='{"version":1,"nodes":[...]}'></rich-text-editor-viewer>
<script src="https://cdn.jsdelivr.net/npm/rich-text-editor-renderer/dist/index.global.js"></script>
```

## CDN

After publishing to npm, the global build will be available from a CDN like:

```html
<script src="https://cdn.jsdelivr.net/npm/rich-text-editor-renderer/dist/index.global.js"></script>
```

Then:

```html
<script>
  RichTextEditorRenderer.renderRichTextDocument({
    element: document.getElementById('viewer'),
    document: savedJsonFromDatabase
  });
</script>
```

## Math

This package emits TeX delimiters for inline and block math.
Load MathJax or KaTeX separately in the host app if you want formulas rendered.
