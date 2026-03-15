# Publishing

This package is prepared for:

- npm install usage
- CDN usage through jsDelivr or unpkg after npm publish

## 1. Log in to npm

```bash
npm adduser
```

Or if you already have an account:

```bash
npm login
```

## 2. Verify package name availability

```bash
npm view rich-text-editor-renderer
```

If the name is already taken, change the `name` field in [package.json](/Users/sakibulhaque/Desktop/Project/dart_package/rich_text_editor/renderer/package.json).

## 3. Build

```bash
npm run build
```

## 4. Publish

```bash
npm publish --access public
```

## 5. CDN URLs after publish

jsDelivr:

```text
https://cdn.jsdelivr.net/npm/rich-text-editor-renderer/dist/index.global.js
```

unpkg:

```text
https://unpkg.com/rich-text-editor-renderer/dist/index.global.js
```

## 6. Example CDN usage

```html
<div id="viewer"></div>
<script src="https://cdn.jsdelivr.net/npm/rich-text-editor-renderer/dist/index.global.js"></script>
<script>
  RichTextEditorRenderer.renderRichTextDocument({
    element: document.getElementById('viewer'),
    document: savedJsonFromDatabase
  });
</script>
```

## Notes

- Public npm publishing is free.
- CDN availability is automatic after npm publish for public packages.
- MathJax or KaTeX is still loaded by the host app, not bundled into this renderer.
