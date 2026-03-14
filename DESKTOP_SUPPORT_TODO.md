# Desktop Support TODO

This package now has example app scaffolding for:

- macOS
- Windows
- Linux

Desktop platforms are not fully validated yet. The current goal is to keep the folders and example targets available, then harden support later.

## Pending Work

- [ ] Run the example app on macOS and verify text editing, toolbar actions, and inline math rendering.
- [ ] Run the example app on Windows and verify keyboard handling for:
  - left/right arrow over inline math
  - shift+left/right selection over inline math
  - backspace/delete near inline math
- [ ] Run the example app on Linux and verify focus and keyboard behavior.
- [ ] Validate tap/click behavior for editing inline math on desktop.
- [ ] Validate image loading and layout behavior on desktop windows.
- [ ] Check desktop text selection consistency inside styled text fields.
- [ ] Add desktop-specific widget/integration tests if platform issues appear.
- [ ] Review platform-specific shortcuts and expected editor UX.

## Notes

- The example app is scaffolded for desktop now, but platform support should still be treated as in-progress.
- Desktop is likely the best place to continue polishing keyboard-driven editor behavior.
