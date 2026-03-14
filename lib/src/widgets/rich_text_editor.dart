import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:rich_text_editor/src/controller/rich_text_editor_controller.dart';
import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/nodes/image_node.dart';
import 'package:rich_text_editor/src/document/nodes/list_node.dart';
import 'package:rich_text_editor/src/document/nodes/math_node.dart';
import 'package:rich_text_editor/src/document/nodes/text_block_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';
import 'package:rich_text_editor/src/math/math_dialog.dart';
import 'package:rich_text_editor/src/widgets/segmented_text_editing_controller.dart';

const double _kMinImageWidth = 32.0;
const double _kMinImageHeight = 28.0;

class _FlowExclusionBand {
  const _FlowExclusionBand({
    required this.top,
    required this.bottom,
    required this.leftInset,
    required this.rightInset,
    required this.blockedStart,
    required this.blockedEnd,
  });

  final double top;
  final double bottom;
  final double leftInset;
  final double rightInset;
  final double blockedStart;
  final double blockedEnd;
}

class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.padding = const EdgeInsets.all(16),
  });

  final RichTextEditorController controller;
  final ValueChanged<String>? onChanged;
  final EdgeInsets padding;

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _nodeKeys = <String, GlobalKey>{};
  final GlobalKey _stackKey = GlobalKey();
  Map<String, Rect> _nodeRects = <String, Rect>{};
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _scrollController.addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNodeRects());
  }

  @override
  void didUpdateWidget(covariant RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final flowNodes = widget.controller.nodes.where((node) {
          return node is! ImageNode ||
              node.layoutMode != ImageLayoutMode.floating;
        }).toList();
        final floatingImages =
            widget.controller.nodes.whereType<ImageNode>().where(
                  (node) => node.layoutMode == ImageLayoutMode.floating,
                );
        final floatingRects = <String, Rect>{
          for (final node in floatingImages)
            node.id: _buildFloatingRect(
              node,
              _nodeRects[node.anchorBlockId],
            ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorToolbar(controller: widget.controller),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      children: [
                        ListView.separated(
                          controller: _scrollController,
                          padding: widget.padding,
                          itemCount: flowNodes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final node = flowNodes[index];
                            final nodeKey =
                                _nodeKeys.putIfAbsent(node.id, GlobalKey.new);
                            final contentPadding = _buildExclusionPadding(
                              node.id,
                              floatingRects,
                            );
                            final exclusionBands = _buildExclusionBands(
                              node.id,
                              floatingRects,
                            );
                            final usesWrappedPreview =
                                (node is TextBlockNode || node is ListNode) &&
                                    exclusionBands.isNotEmpty;
                            return _DocumentNode(
                              key: nodeKey,
                              controller: widget.controller,
                              node: node,
                              contentPadding: usesWrappedPreview
                                  ? const EdgeInsets.only(left: 8)
                                  : contentPadding,
                              exclusionBands: exclusionBands,
                            );
                          },
                        ),
                        ...floatingImages.map(
                          (node) => _FloatingImageOverlay(
                            controller: widget.controller,
                            node: node,
                            viewportSize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            padding: widget.padding,
                            anchorRect: node.anchorBlockId == null
                                ? null
                                : _nodeRects[node.anchorBlockId!],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleControllerChanged() {
    widget.onChanged?.call(widget.controller.toJsonString());
    _scheduleNodeRectRefresh();
  }

  void _handleScrollChanged() {
    _scheduleNodeRectRefresh();
  }

  void _scheduleNodeRectRefresh() {
    if (_refreshScheduled || !mounted) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      _refreshNodeRects();
    });
  }

  void _refreshNodeRects() {
    if (!mounted) {
      return;
    }
    final stackContext = _stackKey.currentContext;
    if (stackContext == null) {
      return;
    }
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) {
      return;
    }
    final nextRects = <String, Rect>{};
    for (final entry in _nodeKeys.entries) {
      final childContext = entry.value.currentContext;
      if (childContext == null) {
        continue;
      }
      final childBox = childContext.findRenderObject() as RenderBox?;
      if (childBox == null || !childBox.hasSize) {
        continue;
      }
      final topLeft = childBox.localToGlobal(Offset.zero, ancestor: stackBox);
      nextRects[entry.key] = topLeft & childBox.size;
    }
    if (_rectMapsEqual(_nodeRects, nextRects)) {
      return;
    }
    setState(() {
      _nodeRects = nextRects;
    });
  }

  bool _rectMapsEqual(Map<String, Rect> a, Map<String, Rect> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Rect _buildFloatingRect(ImageNode node, Rect? anchorRect) {
    final width =
        (node.width ?? 280.0).clamp(_kMinImageWidth, 720.0).toDouble();
    final height = (node.height ?? (width * 0.72))
        .clamp(_kMinImageHeight, 720.0)
        .toDouble();
    final baseLeft = anchorRect?.left ?? widget.padding.left;
    final baseTop = anchorRect?.top ?? widget.padding.top;
    return Rect.fromLTWH(baseLeft + node.x, baseTop + node.y, width, height);
  }

  EdgeInsets _buildExclusionPadding(
    String nodeId,
    Map<String, Rect> floatingRects,
  ) {
    final nodeRect = _nodeRects[nodeId];
    if (nodeRect == null || floatingRects.isEmpty) {
      return const EdgeInsets.only(left: 8);
    }

    double leftInset = 8;
    double rightInset = 0;
    final nodeCenterX = nodeRect.center.dx;
    for (final rect in floatingRects.values) {
      final overlapsVertically =
          rect.bottom > nodeRect.top && rect.top < nodeRect.bottom;
      if (!overlapsVertically) {
        continue;
      }
      if (rect.center.dx <= nodeCenterX) {
        leftInset = leftInset < rect.width + 24 ? rect.width + 24 : leftInset;
      } else {
        rightInset =
            rightInset < rect.width + 24 ? rect.width + 24 : rightInset;
      }
    }

    return EdgeInsets.only(left: leftInset, right: rightInset);
  }

  List<_FlowExclusionBand> _buildExclusionBands(
    String nodeId,
    Map<String, Rect> floatingRects,
  ) {
    final nodeRect = _nodeRects[nodeId];
    if (nodeRect == null || floatingRects.isEmpty) {
      return const <_FlowExclusionBand>[];
    }

    final bands = <_FlowExclusionBand>[];
    final nodeCenterX = nodeRect.center.dx;
    for (final rect in floatingRects.values) {
      final overlapTop = rect.top > nodeRect.top ? rect.top : nodeRect.top;
      final overlapBottom =
          rect.bottom < nodeRect.bottom ? rect.bottom : nodeRect.bottom;
      if (overlapBottom <= overlapTop) {
        continue;
      }
      bands.add(
        _FlowExclusionBand(
          top: overlapTop - nodeRect.top,
          bottom: overlapBottom - nodeRect.top,
          leftInset: rect.center.dx <= nodeCenterX ? rect.width + 24 : 8,
          rightInset: rect.center.dx > nodeCenterX ? rect.width + 24 : 0,
          blockedStart: (rect.left - nodeRect.left).clamp(0.0, nodeRect.width),
          blockedEnd: (rect.right - nodeRect.left).clamp(0.0, nodeRect.width),
        ),
      );
    }
    bands.sort((a, b) => a.top.compareTo(b.top));
    return bands;
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({required this.controller});

  final RichTextEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            FilledButton.tonal(
              onPressed: () {
                controller.insertParagraph();
              },
              child: const Text('Paragraph'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                controller.insertParagraph(style: TextBlockStyle.heading1);
              },
              child: const Text('Heading 1'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: controller.activeTextNodeId != null
                  ? () => controller.applyHeadingToActiveText(
                        TextBlockStyle.paragraph,
                      )
                  : null,
              icon: const Icon(Icons.subject),
              tooltip: 'Make paragraph',
            ),
            IconButton(
              onPressed: controller.activeTextNodeId != null
                  ? () => controller.applyHeadingToActiveText(
                        TextBlockStyle.heading1,
                      )
                  : null,
              icon: const Icon(Icons.title),
              tooltip: 'Make heading',
            ),
            IconButton(
              onPressed: controller.activeTextNodeId != null
                  ? () => controller.convertActiveTextBlockToList(
                        ordered: false,
                      )
                  : null,
              icon: const Icon(Icons.format_list_bulleted),
              tooltip: 'Convert to bullet list',
            ),
            IconButton(
              onPressed: controller.activeTextNodeId != null
                  ? () => controller.convertActiveTextBlockToList(
                        ordered: true,
                      )
                  : null,
              icon: const Icon(Icons.format_list_numbered),
              tooltip: 'Convert to numbered list',
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () async {
                final inlineNodeId =
                    controller.activeTextNodeId ?? controller.lastTextNodeId;
                final inlineSelection = controller.activeSelection.isValid
                    ? controller.activeSelection
                    : controller.lastTextSelection;
                final listNodeId =
                    controller.activeListNodeId ?? controller.lastListNodeId;
                final listItemIndex = controller.activeListItemIndex ??
                    controller.lastListItemIndex;
                final listSelection = controller.activeListSelection.isValid
                    ? controller.activeListSelection
                    : controller.lastListSelection;
                final isInlineTextTarget = inlineNodeId != null &&
                    inlineSelection.isValid &&
                    inlineSelection.start >= 0;
                final isInlineListTarget = listNodeId != null &&
                    listItemIndex != null &&
                    listSelection.isValid &&
                    listSelection.start >= 0;
                final result = await showMathDialog(
                  context,
                  initialDisplayMode: (isInlineTextTarget || isInlineListTarget)
                      ? MathDisplayMode.inline
                      : MathDisplayMode.block,
                );
                if (result == null) {
                  return;
                }
                if (result.displayMode == MathDisplayMode.inline &&
                    isInlineTextTarget) {
                  controller.insertInlineMathAtSelection(
                    nodeId: inlineNodeId,
                    selection: inlineSelection,
                    latex: result.latex,
                  );
                } else if (result.displayMode == MathDisplayMode.inline &&
                    isInlineListTarget) {
                  controller.insertInlineMathAtListItemSelection(
                    nodeId: listNodeId,
                    itemIndex: listItemIndex,
                    selection: listSelection,
                    latex: result.latex,
                  );
                } else if (result.displayMode == MathDisplayMode.inline) {
                  controller.insertParagraph();
                  controller.insertInlineMathAtSelection(
                    nodeId: controller.activeTextNodeId!,
                    selection: controller.activeSelection,
                    latex: result.latex,
                  );
                } else {
                  controller.insertMath(
                    latex: result.latex,
                    displayMode: result.displayMode,
                  );
                }
              },
              child: const Text('Math'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                final result = await showMathDialog(
                  context,
                  initialDisplayMode: MathDisplayMode.block,
                );
                if (result == null) {
                  return;
                }
                controller.insertMath(
                  latex: result.latex,
                  displayMode: MathDisplayMode.block,
                );
              },
              icon: const Icon(Icons.functions),
              tooltip: 'Insert block math',
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                controller.insertList(items: const ['List item']);
              },
              child: const Text('List'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () async {
                final image = await showDialog<_ImageDialogResult>(
                  context: context,
                  builder: (context) => const _ImageDialog(),
                );
                if (image == null || image.url.trim().isEmpty) {
                  return;
                }
                controller.insertImage(
                  url: image.url.trim(),
                  altText: image.altText.trim(),
                  width: image.width,
                  height: image.height,
                  layoutMode: image.layoutMode,
                  textWrapMode: image.textWrapMode,
                  x: image.x,
                  y: image.y,
                  zIndex: image.zIndex,
                  anchorBlockId: image.anchorBlockId ??
                      controller.activeTextNodeId ??
                      controller.activeListNodeId ??
                      controller.selectedNodeId,
                  wrapText: image.wrapText,
                  wrapAlignment: image.wrapAlignment,
                );
              },
              child: const Text('Image'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: controller.activeSelection.isValid &&
                      !controller.activeSelection.isCollapsed
                  ? controller.applyBoldToSelection
                  : null,
              icon: const Icon(Icons.format_bold),
              tooltip: 'Bold',
            ),
            IconButton(
              onPressed: controller.activeSelection.isValid &&
                      !controller.activeSelection.isCollapsed
                  ? controller.applyItalicToSelection
                  : null,
              icon: const Icon(Icons.format_italic),
              tooltip: 'Italic',
            ),
            IconButton(
              onPressed: controller.activeSelection.isValid &&
                      !controller.activeSelection.isCollapsed
                  ? controller.applyUnderlineToSelection
                  : null,
              icon: const Icon(Icons.format_underline),
              tooltip: 'Underline',
            ),
            IconButton(
              onPressed: controller.activeSelection.isValid &&
                      !controller.activeSelection.isCollapsed
                  ? () async {
                      final link = await showDialog<String>(
                        context: context,
                        builder: (context) => const _LinkDialog(),
                      );
                      if (link == null || link.trim().isEmpty) {
                        return;
                      }
                      controller.applyLinkToSelection(link);
                    }
                  : null,
              icon: const Icon(Icons.link),
              tooltip: 'Link',
            ),
            IconButton(
              onPressed: controller.activeSelection.isValid &&
                      !controller.activeSelection.isCollapsed
                  ? controller.clearLinkFromSelection
                  : null,
              icon: const Icon(Icons.link_off),
              tooltip: 'Clear link',
            ),
            IconButton(
              onPressed: controller.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            IconButton(
              onPressed: controller.canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentNode extends StatelessWidget {
  const _DocumentNode({
    super.key,
    required this.controller,
    required this.node,
    this.contentPadding = const EdgeInsets.only(left: 8),
    this.exclusionBands = const <_FlowExclusionBand>[],
  });

  final RichTextEditorController controller;
  final EditorNode node;
  final EdgeInsets contentPadding;
  final List<_FlowExclusionBand> exclusionBands;

  @override
  Widget build(BuildContext context) {
    final child = switch (node) {
      TextBlockNode textNode => _TextBlockEditor(
          controller: controller,
          node: textNode,
          exclusionBands: exclusionBands,
        ),
      MathNode mathNode => _MathBlockEditor(
          controller: controller,
          node: mathNode,
        ),
      ListNode listNode => _ListBlockEditor(
          controller: controller,
          node: listNode,
          exclusionBands: exclusionBands,
        ),
      ImageNode imageNode => _ImageBlockEditor(
          controller: controller,
          node: imageNode,
        ),
      _ => const SizedBox.shrink(),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => controller.selectNode(node.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: controller.selectedNodeId == node.id
                ? Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Padding(
            padding: contentPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TextBlockEditor extends StatefulWidget {
  const _TextBlockEditor({
    required this.controller,
    required this.node,
    this.exclusionBands = const <_FlowExclusionBand>[],
  });

  final RichTextEditorController controller;
  final TextBlockNode node;
  final List<_FlowExclusionBand> exclusionBands;

  @override
  State<_TextBlockEditor> createState() => _TextBlockEditorState();
}

class _TextBlockEditorState extends State<_TextBlockEditor> {
  late final SegmentedTextEditingController _textController;
  late final FocusNode _focusNode;
  int _lastHandledFocusRequestVersion = -1;
  bool _showInlineWrappedEditor = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = SegmentedTextEditingController(
      segments: widget.node.segments,
      onInlineMathTap: _editInlineMathAtSegment,
    );
    _textController.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _TextBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.segments != widget.node.segments) {
      _textController.updateSegments(
        widget.node.segments,
        preferredSelection: widget.controller.activeTextNodeId == widget.node.id
            ? widget.controller.activeSelection
            : null,
      );
    }
    if (widget.exclusionBands.isNotEmpty &&
        widget.controller.activeTextNodeId == widget.node.id &&
        !_showInlineWrappedEditor) {
      _showInlineWrappedEditor = true;
    }
    if (widget.controller.activeTextNodeId == widget.node.id &&
        widget.controller.focusRequestVersion !=
            _lastHandledFocusRequestVersion) {
      _lastHandledFocusRequestVersion = widget.controller.focusRequestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).requestFocus(_focusNode);
        if (widget.controller.activeSelection.isValid) {
          _textController.selection = widget.controller.activeSelection;
        }
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleSelectionChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = switch (widget.node.style) {
      TextBlockStyle.paragraph => Theme.of(context).textTheme.bodyLarge,
      TextBlockStyle.heading1 => Theme.of(context).textTheme.headlineSmall,
      TextBlockStyle.heading2 => Theme.of(context).textTheme.titleLarge,
    };
    final showWrappedPreview = widget.exclusionBands.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWrappedPreview)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                _showInlineWrappedEditor = true;
              });
              widget.controller.setActiveTextSelection(
                widget.node.id,
                _textController.selection.isValid
                    ? _textController.selection
                    : const TextSelection.collapsed(offset: 0),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                FocusScope.of(context).requestFocus(_focusNode);
                SystemChannels.textInput.invokeMethod<void>('TextInput.show');
              });
            },
            child: _WrappedParagraphPreview(
              segments: widget.node.segments,
              textStyle: textStyle ?? Theme.of(context).textTheme.bodyLarge!,
              exclusionBands: widget.exclusionBands,
            ),
          ),
        if (showWrappedPreview && _showInlineWrappedEditor)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _InlineWrappedEditorPanel(
              title: 'Edit wrapped paragraph',
              focusNode: _focusNode,
              controller: _textController,
              textStyle: textStyle,
              hintText: 'Edit wrapped paragraph',
              onClose: () {
                setState(() {
                  _showInlineWrappedEditor = false;
                });
              },
              onTap: () {
                widget.controller.setActiveTextSelection(
                  widget.node.id,
                  _textController.selection,
                );
              },
              onChanged: () {
                widget.controller.syncTextEditingValue(
                  widget.node.id,
                  _textController.value,
                );
              },
            ),
          )
        else
          Focus(
            focusNode: _focusNode,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }

              final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
              final nextValue = switch (event.logicalKey) {
                LogicalKeyboardKey.backspace =>
                  widget.controller.deleteInlineMathAtBoundary(
                    widget.node.id,
                    _textController.value,
                    backward: true,
                  ),
                LogicalKeyboardKey.delete =>
                  widget.controller.deleteInlineMathAtBoundary(
                    widget.node.id,
                    _textController.value,
                    backward: false,
                  ),
                LogicalKeyboardKey.arrowLeft => isShiftPressed
                    ? widget.controller.expandSelectionAcrossInlineMath(
                        widget.node.id,
                        _textController.value,
                        forward: false,
                      )
                    : widget.controller.moveCaretAcrossInlineMath(
                        widget.node.id,
                        _textController.value,
                        forward: false,
                      ),
                LogicalKeyboardKey.arrowRight => isShiftPressed
                    ? widget.controller.expandSelectionAcrossInlineMath(
                        widget.node.id,
                        _textController.value,
                        forward: true,
                      )
                    : widget.controller.moveCaretAcrossInlineMath(
                        widget.node.id,
                        _textController.value,
                        forward: true,
                      ),
                _ => null,
              };

              if (nextValue != null) {
                _textController.value = nextValue;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: null,
              style: textStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start typing',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                widget.controller.setActiveTextSelection(
                  widget.node.id,
                  _textController.selection,
                );
              },
              onChanged: (value) {
                widget.controller.syncTextEditingValue(
                  widget.node.id,
                  _textController.value,
                );
              },
            ),
          ),
      ],
    );
  }

  void _handleSelectionChanged() {
    widget.controller.setActiveTextSelection(
      widget.node.id,
      _textController.selection,
    );
  }

  Future<void> _editInlineMathAtSegment(int segmentIndex) async {
    final segment = widget.controller.inlineMathSegmentAt(
      widget.node.id,
      segmentIndex,
    );
    if (segment == null || !segment.isInlineMath) {
      return;
    }

    final result = await showMathDialog(
      context,
      initialLatex: segment.inlineMathLatex!,
      initialDisplayMode: MathDisplayMode.inline,
    );
    if (result == null || result.latex.trim().isEmpty) {
      return;
    }

    widget.controller.updateInlineMathSegment(
      widget.node.id,
      segmentIndex,
      result.latex,
    );
  }
}

class _WrappedParagraphPreview extends StatelessWidget {
  const _WrappedParagraphPreview({
    required this.segments,
    required this.textStyle,
    required this.exclusionBands,
  });

  final List<TextSegment> segments;
  final TextStyle textStyle;
  final List<_FlowExclusionBand> exclusionBands;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final lineHeight =
            (textStyle.height ?? 1.4) * (textStyle.fontSize ?? 16.0);
        final tokens = _tokenizeWrappedSegments(segments);
        var tokenIndex = 0;
        var currentTop = 0.0;
        final rows = <Widget>[];
        final sortedBands = [...exclusionBands]
          ..sort((a, b) => a.top.compareTo(b.top));

        while (tokenIndex < tokens.length) {
          final activeBand = sortedBands
              .where((band) {
                return currentTop + lineHeight > band.top &&
                    currentTop < band.bottom;
              })
              .cast<_FlowExclusionBand?>()
              .firstWhere(
                (band) => true,
                orElse: () => null,
              );

          if (activeBand == null) {
            final built = _buildWrappedLine(
              tokens: tokens,
              startIndex: tokenIndex,
              width: maxWidth,
              style: textStyle,
            );
            tokenIndex += built.consumed;
            rows.add(_buildPreviewLine(built.tokens, Alignment.centerLeft));
            currentTop += lineHeight;
            continue;
          }

          final leftWidth = activeBand.blockedStart.clamp(0.0, maxWidth);
          final rightWidth =
              (maxWidth - activeBand.blockedEnd).clamp(0.0, maxWidth);
          final leftBuilt = leftWidth > 48
              ? _buildWrappedLine(
                  tokens: tokens,
                  startIndex: tokenIndex,
                  width: leftWidth,
                  style: textStyle,
                )
              : const _WrappedLineResult(<_WrappedPreviewToken>[], 0);
          tokenIndex += leftBuilt.consumed;
          final rightBuilt = rightWidth > 48
              ? _buildWrappedLine(
                  tokens: tokens,
                  startIndex: tokenIndex,
                  width: rightWidth,
                  style: textStyle,
                )
              : const _WrappedLineResult(<_WrappedPreviewToken>[], 0);
          tokenIndex += rightBuilt.consumed;

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: leftWidth,
                  child:
                      _buildPreviewLine(leftBuilt.tokens, Alignment.centerLeft),
                ),
                SizedBox(
                  width: (activeBand.blockedEnd - activeBand.blockedStart)
                      .clamp(0.0, maxWidth),
                ),
                SizedBox(
                  width: rightWidth,
                  child: _buildPreviewLine(
                      rightBuilt.tokens, Alignment.centerLeft),
                ),
              ],
            ),
          );
          currentTop += lineHeight;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }

  Widget _buildPreviewLine(
    List<_WrappedPreviewToken> tokens,
    Alignment alignment,
  ) {
    return Align(
      alignment: alignment,
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
        children: [
          for (final token in tokens)
            token.isMath
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Math.tex(
                      token.value,
                      mathStyle: MathStyle.text,
                      onErrorFallback: (error) => Text(
                        token.value,
                        style: textStyle,
                      ),
                    ),
                  )
                : Text(
                    token.value,
                    style: textStyle,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
        ],
      ),
    );
  }
}

class _WrappedPreviewToken {
  const _WrappedPreviewToken({
    required this.value,
    required this.isMath,
  });

  final String value;
  final bool isMath;
}

class _WrappedLineResult {
  const _WrappedLineResult(this.tokens, this.consumed);

  final List<_WrappedPreviewToken> tokens;
  final int consumed;
}

_WrappedLineResult _buildWrappedLine({
  required List<_WrappedPreviewToken> tokens,
  required int startIndex,
  required double width,
  required TextStyle style,
}) {
  if (startIndex >= tokens.length || width <= 0) {
    return const _WrappedLineResult(<_WrappedPreviewToken>[], 0);
  }
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  final accepted = <_WrappedPreviewToken>[];
  final buffer = StringBuffer();
  var index = startIndex;
  var consumed = 0;

  while (index < tokens.length) {
    final nextToken = tokens[index];
    final nextText = buffer.isEmpty
        ? nextToken.value
        : '${buffer.toString()}${nextToken.value}';
    painter.text = TextSpan(text: nextText, style: style);
    painter.layout(maxWidth: width);
    if (painter.didExceedMaxLines || painter.width > width) {
      break;
    }
    buffer
      ..clear()
      ..write(nextText);
    accepted.add(nextToken);
    index += 1;
    consumed += 1;
  }

  if (consumed == 0) {
    return _WrappedLineResult(<_WrappedPreviewToken>[tokens[startIndex]], 1);
  }
  return _WrappedLineResult(accepted, consumed);
}

List<_WrappedPreviewToken> _tokenizeWrappedSegments(
    List<TextSegment> segments) {
  final tokens = <_WrappedPreviewToken>[];
  for (final segment in segments) {
    if (segment.isInlineMath) {
      tokens.add(
        _WrappedPreviewToken(
          value: segment.inlineMathLatex!,
          isMath: true,
        ),
      );
      tokens.add(const _WrappedPreviewToken(value: ' ', isMath: false));
      continue;
    }
    final matches = RegExp(r'\S+\s*').allMatches(segment.text);
    if (matches.isEmpty && segment.text.isNotEmpty) {
      tokens.add(_WrappedPreviewToken(value: segment.text, isMath: false));
      continue;
    }
    for (final match in matches) {
      tokens.add(
        _WrappedPreviewToken(
          value: match.group(0)!,
          isMath: false,
        ),
      );
    }
  }
  return tokens;
}

class _MathBlockEditor extends StatelessWidget {
  const _MathBlockEditor({required this.controller, required this.node});

  final RichTextEditorController controller;
  final MathNode node;

  Future<void> _editMath(BuildContext context) async {
    final result = await showMathDialog(
      context,
      initialLatex: node.latex,
      initialDisplayMode: node.displayMode,
    );
    if (result == null) {
      return;
    }
    controller.updateMathNodeState(
      node.id,
      latex: result.latex,
      displayMode: result.displayMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _editMath(context),
          onDoubleTap: () => _editMath(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Align(
              alignment:
                  node.isInline ? Alignment.centerLeft : Alignment.center,
              child: Math.tex(
                node.latex,
                mathStyle: node.isInline ? MathStyle.text : MathStyle.display,
                onErrorFallback: (error) {
                  return Text(
                    'Invalid LaTeX: ${error.message}',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListBlockEditor extends StatefulWidget {
  const _ListBlockEditor({
    required this.controller,
    required this.node,
    this.exclusionBands = const <_FlowExclusionBand>[],
  });

  final RichTextEditorController controller;
  final ListNode node;
  final List<_FlowExclusionBand> exclusionBands;

  @override
  State<_ListBlockEditor> createState() => _ListBlockEditorState();
}

class _ListBlockEditorState extends State<_ListBlockEditor> {
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  Map<int, Rect> _itemRects = <int, Rect>{};
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshItemRects());
  }

  @override
  void didUpdateWidget(covariant _ListBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.items != widget.node.items ||
        oldWidget.exclusionBands != widget.exclusionBands) {
      _scheduleItemRectRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.node.items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  child: Text(
                    widget.node.style == ListStyle.ordered ? '${i + 1}.' : '•',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Expanded(
                  child: Container(
                    key: _itemKeys.putIfAbsent(i, GlobalKey.new),
                    child: _ListItemEditor(
                      controller: widget.controller,
                      node: widget.node,
                      itemIndex: i,
                      exclusionBands: _bandsForItem(i),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _scheduleItemRectRefresh() {
    if (_refreshScheduled || !mounted) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      _refreshItemRects();
    });
  }

  void _refreshItemRects() {
    if (!mounted) {
      return;
    }
    final parentBox = context.findRenderObject() as RenderBox?;
    if (parentBox == null || !parentBox.hasSize) {
      return;
    }
    final nextRects = <int, Rect>{};
    for (final entry in _itemKeys.entries) {
      final itemContext = entry.value.currentContext;
      if (itemContext == null) {
        continue;
      }
      final itemBox = itemContext.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.hasSize) {
        continue;
      }
      final topLeft = itemBox.localToGlobal(Offset.zero, ancestor: parentBox);
      nextRects[entry.key] = topLeft & itemBox.size;
    }
    if (_rectMapsEqual(_itemRects, nextRects)) {
      return;
    }
    setState(() {
      _itemRects = nextRects;
    });
  }

  List<_FlowExclusionBand> _bandsForItem(int itemIndex) {
    final itemRect = _itemRects[itemIndex];
    if (itemRect == null || widget.exclusionBands.isEmpty) {
      return const <_FlowExclusionBand>[];
    }

    final bands = <_FlowExclusionBand>[];
    for (final band in widget.exclusionBands) {
      final overlapTop = band.top > itemRect.top ? band.top : itemRect.top;
      final overlapBottom =
          band.bottom < itemRect.bottom ? band.bottom : itemRect.bottom;
      if (overlapBottom <= overlapTop) {
        continue;
      }
      bands.add(
        _FlowExclusionBand(
          top: overlapTop - itemRect.top,
          bottom: overlapBottom - itemRect.top,
          leftInset: band.leftInset,
          rightInset: band.rightInset,
          blockedStart: band.blockedStart,
          blockedEnd: band.blockedEnd,
        ),
      );
    }
    return bands;
  }

  bool _rectMapsEqual(Map<int, Rect> a, Map<int, Rect> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

class _ListItemEditor extends StatefulWidget {
  const _ListItemEditor({
    required this.controller,
    required this.node,
    required this.itemIndex,
    this.exclusionBands = const <_FlowExclusionBand>[],
  });

  final RichTextEditorController controller;
  final ListNode node;
  final int itemIndex;
  final List<_FlowExclusionBand> exclusionBands;

  @override
  State<_ListItemEditor> createState() => _ListItemEditorState();
}

class _ListItemEditorState extends State<_ListItemEditor> {
  late final SegmentedTextEditingController _textController;
  late final FocusNode _focusNode;
  int _lastHandledFocusRequestVersion = -1;
  bool _showInlineWrappedEditor = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = SegmentedTextEditingController(
      segments: widget.node.items[widget.itemIndex],
      onInlineMathTap: _editInlineMathAtSegment,
    )..addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _ListItemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.items[oldWidget.itemIndex] !=
        widget.node.items[widget.itemIndex]) {
      _textController.updateSegments(
        widget.node.items[widget.itemIndex],
        preferredSelection:
            widget.controller.activeListNodeId == widget.node.id &&
                    widget.controller.activeListItemIndex == widget.itemIndex
                ? widget.controller.activeListSelection
                : null,
      );
    }
    if (widget.controller.activeListNodeId == widget.node.id &&
        widget.controller.activeListItemIndex == widget.itemIndex &&
        !_showInlineWrappedEditor &&
        widget.exclusionBands.isNotEmpty) {
      _showInlineWrappedEditor = true;
    }
    if (widget.controller.activeListNodeId == widget.node.id &&
        widget.controller.activeListItemIndex == widget.itemIndex &&
        widget.controller.focusRequestVersion !=
            _lastHandledFocusRequestVersion) {
      _lastHandledFocusRequestVersion = widget.controller.focusRequestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).requestFocus(_focusNode);
        if (widget.controller.activeListSelection.isValid) {
          _textController.selection = widget.controller.activeListSelection;
        }
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_handleSelectionChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showWrappedPreview = widget.exclusionBands.isNotEmpty;
    if (showWrappedPreview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                _showInlineWrappedEditor = true;
              });
              widget.controller.setActiveListItemSelection(
                widget.node.id,
                widget.itemIndex,
                _textController.selection.isValid
                    ? _textController.selection
                    : const TextSelection.collapsed(offset: 0),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                FocusScope.of(context).requestFocus(_focusNode);
                SystemChannels.textInput.invokeMethod<void>('TextInput.show');
              });
            },
            child: _WrappedParagraphPreview(
              segments: widget.node.items[widget.itemIndex],
              textStyle:
                  Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
              exclusionBands: widget.exclusionBands,
            ),
          ),
          if (_showInlineWrappedEditor)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InlineWrappedEditorPanel(
                title: 'Edit wrapped list item',
                focusNode: _focusNode,
                controller: _textController,
                hintText: 'Edit wrapped list item',
                onClose: () {
                  setState(() {
                    _showInlineWrappedEditor = false;
                  });
                },
                onTap: () {
                  widget.controller.setActiveListItemSelection(
                    widget.node.id,
                    widget.itemIndex,
                    _textController.selection,
                  );
                },
                onChanged: () {
                  widget.controller.syncListItemEditingValue(
                    widget.node.id,
                    widget.itemIndex,
                    _textController.value,
                  );
                },
              ),
            ),
        ],
      );
    }
    return Focus(
      focusNode: _focusNode,
      child: TextField(
        controller: _textController,
        minLines: 1,
        maxLines: null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'List item',
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onTap: () {
          widget.controller.setActiveListItemSelection(
            widget.node.id,
            widget.itemIndex,
            _textController.selection,
          );
        },
        onChanged: (_) {
          widget.controller.syncListItemEditingValue(
            widget.node.id,
            widget.itemIndex,
            _textController.value,
          );
        },
      ),
    );
  }

  void _handleSelectionChanged() {
    widget.controller.setActiveListItemSelection(
      widget.node.id,
      widget.itemIndex,
      _textController.selection,
    );
  }

  Future<void> _editInlineMathAtSegment(int segmentIndex) async {
    final segment = widget.controller.listInlineMathSegmentAt(
      widget.node.id,
      widget.itemIndex,
      segmentIndex,
    );
    if (segment == null || !segment.isInlineMath) {
      return;
    }
    final result = await showMathDialog(
      context,
      initialLatex: segment.inlineMathLatex!,
      initialDisplayMode: MathDisplayMode.inline,
    );
    if (result == null || result.latex.trim().isEmpty) {
      return;
    }
    widget.controller.updateListInlineMathSegment(
      widget.node.id,
      widget.itemIndex,
      segmentIndex,
      result.latex,
    );
  }
}

class _ImageBlockEditor extends StatefulWidget {
  const _ImageBlockEditor({required this.controller, required this.node});

  final RichTextEditorController controller;
  final ImageNode node;

  @override
  State<_ImageBlockEditor> createState() => _ImageBlockEditorState();
}

class _FloatingImageOverlay extends StatelessWidget {
  const _FloatingImageOverlay({
    required this.controller,
    required this.node,
    required this.viewportSize,
    required this.padding,
    required this.anchorRect,
  });

  final RichTextEditorController controller;
  final ImageNode node;
  final Size viewportSize;
  final EdgeInsets padding;
  final Rect? anchorRect;

  @override
  Widget build(BuildContext context) {
    final width =
        (node.width ?? 280.0).clamp(_kMinImageWidth, 720.0).toDouble();
    final height = (node.height ?? (width * 0.72))
        .clamp(_kMinImageHeight, 720.0)
        .toDouble();
    final baseLeft = anchorRect?.left ?? padding.left;
    final baseTop = anchorRect?.top ?? padding.top;
    final minLeft = padding.left;
    final minTop = padding.top;
    final maxLeft = (viewportSize.width - padding.right - width)
        .clamp(minLeft, double.infinity)
        .toDouble();
    final maxTop = (viewportSize.height - padding.bottom - height)
        .clamp(minTop, double.infinity)
        .toDouble();
    final left = (baseLeft + node.x).clamp(minLeft, maxLeft).toDouble();
    final top = (baseTop + node.y).clamp(minTop, maxTop).toDouble();
    final isSelected = controller.selectedNodeId == node.id;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.selectNode(node.id),
        onPanStart: (_) => controller.selectNode(node.id),
        onPanUpdate: (details) {
          controller.updateFloatingImageGeometry(
            node.id,
            x: node.x + details.delta.dx,
            y: node.y + details.delta.dy,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: _EditorImage(
                    url: node.url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                right: -14,
                bottom: -14,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => controller.selectNode(node.id),
                  onPanUpdate: (details) {
                    final nextWidth = (width + details.delta.dx).clamp(
                      _kMinImageWidth,
                      viewportSize.width - padding.horizontal,
                    );
                    final nextHeight = (height + details.delta.dy).clamp(
                      _kMinImageHeight,
                      viewportSize.height - padding.vertical,
                    );
                    controller.updateFloatingImageGeometry(
                      node.id,
                      width: nextWidth,
                      height: nextHeight,
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.open_in_full,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageBlockEditorState extends State<_ImageBlockEditor> {
  late final SegmentedTextEditingController _wrapTextController;

  @override
  void initState() {
    super.initState();
    _wrapTextController = SegmentedTextEditingController(
      segments: widget.node.wrapSegments,
      onInlineMathTap: _editWrapInlineMathAtSegment,
    );
  }

  @override
  void didUpdateWidget(covariant _ImageBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.wrapSegments != widget.node.wrapSegments) {
      _wrapTextController.updateSegments(widget.node.wrapSegments);
    }
  }

  @override
  void dispose() {
    _wrapTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final node = widget.node;
    final imageWidget = GestureDetector(
      onDoubleTap: () async {
        final result = await showDialog<_ImageDialogResult>(
          context: context,
          builder: (context) => _ImageDialog(
            initialUrl: node.url,
            initialAltText: node.altText,
            initialWidth: node.width,
            initialHeight: node.height,
            initialLayoutMode: node.layoutMode,
            initialTextWrapMode: node.textWrapMode,
            initialX: node.x,
            initialY: node.y,
            initialZIndex: node.zIndex,
            initialAnchorBlockId: node.anchorBlockId,
            initialWrapText: node.wrapText,
            initialWrapAlignment: node.wrapAlignment,
          ),
        );
        if (result == null || result.url.trim().isEmpty) {
          return;
        }
        controller.updateImageNode(
          node.id,
          url: result.url.trim(),
          altText: result.altText.trim(),
          width: result.width,
          height: result.height,
          layoutMode: result.layoutMode,
          textWrapMode: result.textWrapMode,
          x: result.x,
          y: result.y,
          zIndex: result.zIndex,
          anchorBlockId: result.anchorBlockId,
          wrapText: result.wrapText,
          wrapAlignment: result.wrapAlignment,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: _EditorImage(
            url: node.url,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
    final wrapEnabled = node.layoutMode == ImageLayoutMode.block &&
        node.wrapAlignment != ImageWrapAlignment.none;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final requestedImageWidth = (node.width ?? 280.0).toDouble();
        final maxBlockWidth =
            (availableWidth - 8).clamp(_kMinImageWidth, 720.0).toDouble();
        final maxWrappedWidth =
            (availableWidth * 0.48).clamp(_kMinImageWidth, 320.0).toDouble();
        final resolvedImageWidth = wrapEnabled
            ? requestedImageWidth
                .clamp(_kMinImageWidth, maxWrappedWidth)
                .toDouble()
            : requestedImageWidth
                .clamp(_kMinImageWidth, maxBlockWidth)
                .toDouble();
        final imageHeight = (resolvedImageWidth * 0.72)
            .clamp(_kMinImageHeight, 320.0)
            .toDouble();
        final shouldStackWrap = wrapEnabled && availableWidth < 560;
        final wrapTextField = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: shouldStackWrap ? 140.0 : imageHeight,
            maxHeight: shouldStackWrap ? 220.0 : imageHeight,
          ),
          child: TextField(
            controller: _wrapTextController,
            minLines: null,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Text beside image',
            ),
            onChanged: (value) {
              controller.updateImageWrapSegments(
                node.id,
                _wrapTextController.value,
              );
            },
          ),
        );
        final constrainedImage = SizedBox(
          width: resolvedImageWidth,
          height: imageHeight,
          child: imageWidget,
        );

        Widget content;
        if (!wrapEnabled) {
          content = constrainedImage;
        } else if (shouldStackWrap) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              constrainedImage,
              const SizedBox(height: 12),
              wrapTextField,
            ],
          );
        } else if (node.wrapAlignment == ImageWrapAlignment.left) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              constrainedImage,
              const SizedBox(width: 16),
              Expanded(child: wrapTextField),
            ],
          );
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: wrapTextField),
              const SizedBox(width: 16),
              constrainedImage,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node.layoutMode == ImageLayoutMode.floating) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Floating image placeholder',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
            content,
            if (node.altText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                node.altText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _editWrapInlineMathAtSegment(int segmentIndex) async {
    final segment = widget.controller.imageWrapInlineMathSegmentAt(
      widget.node.id,
      segmentIndex,
    );
    if (segment == null || !segment.isInlineMath) {
      return;
    }
    final result = await showMathDialog(
      context,
      initialLatex: segment.inlineMathLatex!,
      initialDisplayMode: MathDisplayMode.inline,
    );
    if (result == null || result.latex.trim().isEmpty) {
      return;
    }
    widget.controller.updateImageWrapInlineMathSegment(
      widget.node.id,
      segmentIndex,
      result.latex,
    );
  }
}

class _ImageDialog extends StatefulWidget {
  const _ImageDialog({
    this.initialUrl = '',
    this.initialAltText = '',
    this.initialWidth,
    this.initialHeight,
    this.initialLayoutMode = ImageLayoutMode.floating,
    this.initialTextWrapMode = ImageTextWrap.around,
    this.initialX = 0,
    this.initialY = 0,
    this.initialZIndex = 0,
    this.initialAnchorBlockId,
    this.initialWrapText = '',
    this.initialWrapAlignment = ImageWrapAlignment.none,
  });

  final String initialUrl;
  final String initialAltText;
  final double? initialWidth;
  final double? initialHeight;
  final ImageLayoutMode initialLayoutMode;
  final ImageTextWrap initialTextWrapMode;
  final double initialX;
  final double initialY;
  final int initialZIndex;
  final String? initialAnchorBlockId;
  final String initialWrapText;
  final ImageWrapAlignment initialWrapAlignment;

  @override
  State<_ImageDialog> createState() => _ImageDialogState();
}

class _ImageDialogState extends State<_ImageDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _altTextController;
  late final TextEditingController _wrapTextController;
  late double _width;
  late double _height;
  late ImageLayoutMode _layoutMode;
  late ImageTextWrap _textWrapMode;
  late double _x;
  late double _y;
  late int _zIndex;
  late String? _anchorBlockId;
  late ImageWrapAlignment _wrapAlignment;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _altTextController = TextEditingController(text: widget.initialAltText);
    _wrapTextController = TextEditingController(text: widget.initialWrapText);
    _width = widget.initialWidth ?? 280;
    _height = widget.initialHeight ?? (_width * 0.72);
    _layoutMode = widget.initialLayoutMode;
    _textWrapMode = widget.initialTextWrapMode;
    _x = widget.initialX;
    _y = widget.initialY;
    _zIndex = widget.initialZIndex;
    _anchorBlockId = widget.initialAnchorBlockId;
    _wrapAlignment = widget.initialWrapAlignment;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _altTextController.dispose();
    _wrapTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Image'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImageFromFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose file'),
                    ),
                    Text(
                      'Width: ${_width.round()} px',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Slider(
                value: _width,
                min: _kMinImageWidth,
                max: 720,
                divisions: 24,
                label: '${_width.round()} px',
                onChanged: (value) {
                  setState(() {
                    final previousWidth = _width <= 0 ? value : _width;
                    _width = value;
                    _height = (_height * (value / previousWidth))
                        .clamp(_kMinImageHeight, 720.0);
                  });
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<ImageLayoutMode>(
                  segments: const [
                    ButtonSegment(
                      value: ImageLayoutMode.block,
                      label: Text('Block'),
                    ),
                    ButtonSegment(
                      value: ImageLayoutMode.floating,
                      label: Text('Floating'),
                    ),
                  ],
                  selected: <ImageLayoutMode>{_layoutMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _layoutMode = selection.first;
                      _textWrapMode = _layoutMode == ImageLayoutMode.floating
                          ? ImageTextWrap.around
                          : ImageTextWrap.none;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _altTextController,
                decoration: const InputDecoration(
                  labelText: 'Alt text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_layoutMode == ImageLayoutMode.block) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ImageWrapAlignment>(
                    segments: const [
                      ButtonSegment(
                        value: ImageWrapAlignment.none,
                        label: Text('No Wrap'),
                      ),
                      ButtonSegment(
                        value: ImageWrapAlignment.left,
                        label: Text('Image Left'),
                      ),
                      ButtonSegment(
                        value: ImageWrapAlignment.right,
                        label: Text('Image Right'),
                      ),
                    ],
                    selected: <ImageWrapAlignment>{_wrapAlignment},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _wrapAlignment = selection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wrapTextController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Text beside image',
                    hintText: 'Type text that should sit beside the image',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Floating mode stores geometry now. Dragging, free placement, and text reflow around the image will be added in the next phases.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (_urlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final previewWidth = _width
                        .clamp(
                          _kMinImageWidth,
                          (constraints.maxWidth - 24)
                              .clamp(_kMinImageWidth, 320.0),
                        )
                        .toDouble();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: previewWidth,
                          child: _EditorImage(
                            url: _urlController.text.trim(),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ImageDialogResult(
                url: _urlController.text,
                altText: _altTextController.text,
                width: _width,
                height: _height,
                layoutMode: _layoutMode,
                textWrapMode: _textWrapMode,
                x: _x,
                y: _y,
                zIndex: _zIndex,
                anchorBlockId: _anchorBlockId,
                wrapText: _wrapTextController.text,
                wrapAlignment: _wrapAlignment,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickImageFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = _mimeTypeForExtension(extension);
    final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
    setState(() {
      _urlController.text = dataUri;
      if (_altTextController.text.trim().isEmpty) {
        _altTextController.text = file.name;
      }
    });
  }
}

class _ImageDialogResult {
  const _ImageDialogResult({
    required this.url,
    required this.altText,
    required this.width,
    required this.height,
    required this.layoutMode,
    required this.textWrapMode,
    required this.x,
    required this.y,
    required this.zIndex,
    required this.anchorBlockId,
    required this.wrapText,
    required this.wrapAlignment,
  });

  final String url;
  final String altText;
  final double width;
  final double height;
  final ImageLayoutMode layoutMode;
  final ImageTextWrap textWrapMode;
  final double x;
  final double y;
  final int zIndex;
  final String? anchorBlockId;
  final String wrapText;
  final ImageWrapAlignment wrapAlignment;
}

class _EditorImage extends StatelessWidget {
  const _EditorImage({
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final memoryBytes = _tryDecodeDataUri(url);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _ImageLoadError(),
      );
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _ImageLoadError(),
    );
  }
}

class _ImageLoadError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        'Unable to load image',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

Uint8List? _tryDecodeDataUri(String value) {
  if (!value.startsWith('data:image/')) {
    return null;
  }
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) {
    return null;
  }
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

String _mimeTypeForExtension(String extension) {
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    _ => 'image/png',
  };
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'https://');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Link'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'URL',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
