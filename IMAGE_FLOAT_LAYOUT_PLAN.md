# Image Float Layout Plan

## Goal

Build a true floating image system for the Flutter-native editor so a user can:

- insert an image anywhere in the document
- drag the image to a position inside the editor canvas
- resize the image directly in the editor
- type text and formulas before the image
- type text and formulas after the image
- have text flow around the image where space exists
- continue typing on the left and right side of the image when layout allows
- press `Enter` to move to the next line below the image

This replaces the current "image block with side text" approach.

## What The Current System Cannot Do

- It treats images as block nodes.
- Wrapped text is stored in a separate text area beside the image.
- Text from the main document does not reflow around the image.
- The image cannot be dragged freely inside the document.
- Left-side and right-side text at the same time is not supported.

## Correct Architecture

### 1. Floating Image Node

Add a new image mode to the document model:

- `block`
- `floating`

Floating image data should include:

- `id`
- `url`
- `altText`
- `width`
- `height`
- `x`
- `y`
- `zIndex`
- `anchorBlockId`
- `layoutMode`
- `textWrapMode`

Recommended enum values:

- `ImageLayoutMode.block`
- `ImageLayoutMode.floating`

Recommended wrap values:

- `ImageTextWrap.none`
- `ImageTextWrap.around`

### 2. Editor Canvas Layout Layer

Add a layout engine above normal document rendering.

Responsibilities:

- compute image rectangle positions
- compute exclusion zones for floating images
- split text lines around occupied image space
- allow text to appear on both left and right side if enough width exists
- continue normal full-width layout when cursor moves below image bottom

### 3. Paragraph Line Breaking With Exclusion Zones

Text blocks must no longer render as one normal `TextField` region when a floating image intersects them.

Need a line layout pipeline that:

- measures available line width per vertical slice
- subtracts occupied image rectangles from that width
- creates left and right text columns around the image if needed
- places caret positions inside those reflowed regions

### 4. Unified Inline Content Model

Text, inline math, links, formatting, and future inline images should all work in the same line layout system.

The line engine must support:

- text segments
- inline math segments
- link spans
- bold/italic/underline spans
- selection ranges
- caret positions

### 5. Interaction Layer

Floating images need direct manipulation:

- drag to move
- drag handles to resize
- tap to select
- double tap to edit metadata
- keyboard delete when selected

## Required Data Model Changes

### Image Node

Add fields to `ImageNode`:

- `ImageLayoutMode layoutMode`
- `ImageTextWrap textWrapMode`
- `double? height`
- `double x`
- `double y`
- `String? anchorBlockId`

Keep backward compatibility:

- old image nodes load as `layoutMode.block`
- old wrap settings map to block behavior only

### Editor Selection Model

Need selection support for:

- floating image selected state
- image resize interaction state
- drag interaction state
- text selection while image exists in overlapping vertical range

## Rendering Strategy

### Phase 1: Floating Overlay

Render floating images in a `Stack` above the document content:

- base layer: document text/math rendering
- overlay layer: positioned floating images

This is the first practical step because it allows:

- dragging
- resizing
- selecting

before full text reflow is complete.

### Phase 2: Exclusion-Based Text Reflow

Once overlay works, introduce exclusion-aware text layout:

- line builder checks which floating images overlap each vertical band
- available width is reduced
- line fragments are created left and right of the image

### Phase 3: Caret And Selection Integration

After text reflow:

- caret must navigate correctly across split line fragments
- selection must span around floating image boundaries
- `Enter` must continue below image when appropriate

## Editing Behavior Requirements

### Insert Image

When user inserts image:

- choose file
- insert at current block/caret anchor
- initial position appears near current insertion point
- default to `floating` if user chooses free layout
- default to `block` if user wants normal image paragraph

### Drag Image

When image is selected:

- drag updates `x` and `y`
- image remains inside editor canvas bounds
- text reflows live or on drag end

### Resize Image

When image is selected:

- show corner handles
- preserve aspect ratio by default
- optional unlock ratio later

### Typing Around Image

User should be able to:

- click left side of image and type
- click right side of image and type
- click below image and type full width
- insert inline math in those text runs

## Math And Formula Requirements

Floating-image layout must work with:

- inline math segments in reflowed text
- block math above or below image
- formulas on either side of a floating image where width permits

## Serialization Requirements

### JSON

Need to store:

- image layout mode
- wrap mode
- geometry
- anchor block id

### HTML

Need two output strategies:

1. faithful editor export
- absolute/floating positioning wrappers

2. simplified content export
- image placed near anchor block
- CSS class for float behavior

## Platform Constraints

This will be hardest on:

- mobile selection/caret behavior
- desktop drag precision

This is feasible on:

- Android
- iOS
- Web
- macOS
- Windows
- Linux

But the input behavior must be validated per platform.

## Implementation Phases

### Phase 1: Foundation

- [ ] Add `layoutMode` and geometry fields to `ImageNode`
- [ ] Add backward-compatible JSON parsing
- [ ] Add image selected state and drag state in controller
- [ ] Rename current confusing wrap labels in UI
- [ ] Keep current block image path intact

### Phase 2: Floating Image Interaction

- [ ] Render floating images in overlay `Stack`
- [ ] Add tap-to-select for floating image
- [ ] Add drag-to-move
- [ ] Add drag handles for resize
- [ ] Add controller updates for image geometry

### Phase 3: Text Reflow Engine

- [ ] Introduce exclusion-aware line layout
- [ ] Split text lines around floating image rects
- [ ] Support text on both left and right side of image
- [ ] Support inline math in reflowed lines
- [ ] Keep normal full-width layout below image bottom

### Phase 4: Editing Integration

- [ ] Map caret positions into split line fragments
- [ ] Support selection across wrapped regions
- [ ] Support `Enter` below image
- [ ] Support delete/backspace near image boundaries

### Phase 5: Export And Polish

- [ ] JSON export/import for floating images
- [ ] HTML export strategy for floating images
- [ ] Accessibility labels and keyboard selection
- [ ] Mobile handle sizing and touch polish
- [ ] Performance tuning for many images

## MVP Recommendation

The correct MVP is:

- floating image overlay
- drag
- resize
- text reflow around one image per local viewport region
- inline math preserved in wrapped text

Do not start with:

- multiple overlapping floating images
- arbitrary z-index editing UI
- rotation
- freeform text boxes

## Key Decision

Do not extend the current "side text beside image" block model further.

That model cannot evolve cleanly into:

- text on both sides
- free dragging
- real paragraph flow around image

This feature should be implemented as a new floating-image layout system.
