# Next Update TODO

## Image And Wrap Follow-up

- [ ] Add a real crop UI for images
- [ ] Add a proper layering panel for bring forward, send backward, bring to front, send to back
- [ ] Add richer snap tooling with visible alignment targets and smarter object-to-object snapping
- [ ] Add alignment actions for floating images
- [ ] Add image lock/unlock support to prevent accidental drag or resize
- [ ] Add image caption support
- [ ] Add image opacity and border controls

## Wrapped Editing Engine

- [ ] Replace hidden-input wrapped editing with a true in-place wrapped editing surface
- [ ] Support caret movement directly inside left and right wrapped regions
- [ ] Support selection drag across wrapped regions
- [ ] Support backspace, delete, and arrow behavior directly inside wrapped regions
- [ ] Support enter/newline behavior that respects floating-image wrap regions
- [ ] Improve wrapped editing around inline math at every caret position
- [ ] Remove remaining fallback behavior that still depends on standard `TextField` assumptions

## Performance And Polish

- [ ] Further reduce floating-image drag jank on low-end mobile devices
- [ ] Add throttled geometry commits or frame-synced overlay updates if needed
- [ ] Add more tests for wrapped paragraph/list layout around floating images
- [ ] Add tests for rotation, deletion, and snap behavior
- [ ] Add example scenarios for multiple floating images in the same document
