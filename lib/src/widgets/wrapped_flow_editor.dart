import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';
import 'package:rich_text_editor/src/widgets/segmented_text_editing_controller.dart';

class FlowExclusionBand {
  const FlowExclusionBand({
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

class WrappedParagraphPreview extends StatelessWidget {
  const WrappedParagraphPreview({
    super.key,
    required this.segments,
    required this.textStyle,
    required this.exclusionBands,
    this.selection,
    this.showCaret = false,
    this.onSelectionChanged,
    this.onInlineMathTap,
  });

  final List<TextSegment> segments;
  final TextStyle textStyle;
  final List<FlowExclusionBand> exclusionBands;
  final TextSelection? selection;
  final bool showCaret;
  final ValueChanged<TextSelection>? onSelectionChanged;
  final ValueChanged<int>? onInlineMathTap;

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
        final caretOffset = selection?.isValid == true && selection!.isCollapsed
            ? selection!.extentOffset.clamp(
                0,
                segments.fold<int>(
                    0, (sum, segment) => sum + segment.plainTextLength),
              )
            : -1;
        var tokenIndex = 0;
        var currentTop = 0.0;
        final rows = <Widget>[];
        final sortedBands = [...exclusionBands]
          ..sort((a, b) => a.top.compareTo(b.top));

        while (tokenIndex < tokens.length) {
          final activeBand = sortedBands
              .where(
                (band) =>
                    currentTop + lineHeight > band.top &&
                    currentTop < band.bottom,
              )
              .cast<FlowExclusionBand?>()
              .firstWhere((band) => true, orElse: () => null);

          if (activeBand == null) {
            final built = _buildWrappedLine(
              tokens: tokens,
              startIndex: tokenIndex,
              width: maxWidth,
              style: textStyle,
            );
            tokenIndex += built.consumed;
            rows.add(
              _buildPreviewLine(
                built.tokens,
                Alignment.centerLeft,
                caretOffset,
              ),
            );
            currentTop += lineHeight;
            continue;
          }

          final rawLeftWidth = activeBand.blockedStart.clamp(0.0, maxWidth);
          final rawBlockedWidth =
              (activeBand.blockedEnd - activeBand.blockedStart)
                  .clamp(0.0, maxWidth);
          final leftWidth = rawLeftWidth.toDouble();
          final blockedWidth =
              rawBlockedWidth.clamp(0.0, maxWidth - leftWidth).toDouble();
          final rightWidth =
              (maxWidth - leftWidth - blockedWidth).clamp(0.0, maxWidth);
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
                  child: _buildPreviewLine(
                    leftBuilt.tokens,
                    Alignment.centerLeft,
                    caretOffset,
                  ),
                ),
                SizedBox(
                  width: blockedWidth,
                ),
                SizedBox(
                  width: rightWidth,
                  child: _buildPreviewLine(
                    rightBuilt.tokens,
                    Alignment.centerLeft,
                    caretOffset,
                  ),
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
    int caretOffset,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTokenWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(20.0, double.infinity)
            : 120.0;
        return Align(
          alignment: alignment,
          child: ClipRect(
            child: SizedBox(
              width:
                  constraints.maxWidth.isFinite ? constraints.maxWidth : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildPreviewWidgets(
                    tokens,
                    caretOffset,
                    maxTokenWidth,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPreviewWidgets(
    List<_WrappedPreviewToken> tokens,
    int caretOffset,
    double maxTokenWidth,
  ) {
    if (!showCaret) {
      return _buildStaticPreviewWidgets(tokens, maxTokenWidth);
    }
    final widgets = <Widget>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      widgets.add(_buildCaretSlot(token.startOffset, caretOffset));
      if (token.isMath) {
        widgets.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (onInlineMathTap != null && token.segmentIndex != null) {
                onInlineMathTap!(token.segmentIndex!);
                return;
              }
              _moveCaret(token.endOffset);
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTokenWidth),
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      token.value,
                      mathStyle: MathStyle.text,
                      onErrorFallback: (error) => Text(
                        token.value,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _moveCaret(token.endOffset),
            child: Text(
              token.value,
              style: textStyle,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      }
      if (i == tokens.length - 1) {
        widgets.add(_buildCaretSlot(token.endOffset, caretOffset));
      }
    }

    if (tokens.isEmpty) {
      widgets.add(_buildCaretSlot(0, caretOffset));
    }
    return widgets;
  }

  List<Widget> _buildStaticPreviewWidgets(
    List<_WrappedPreviewToken> tokens,
    double maxTokenWidth,
  ) {
    return [
      for (final token in tokens)
        token.isMath
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTokenWidth),
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Math.tex(
                        token.value,
                        mathStyle: MathStyle.text,
                        onErrorFallback: (error) => Text(
                          token.value,
                          style: textStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Text(
                token.value,
                style: textStyle,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
    ];
  }

  Widget _buildCaretSlot(int offset, int caretOffset) {
    final isActive = showCaret && caretOffset == offset;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _moveCaret(offset),
      child: SizedBox(
        width: 8,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 2,
            height: (textStyle.fontSize ?? 16) * 1.25,
            color:
                isActive ? textStyle.color ?? Colors.black : Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _moveCaret(int offset) {
    if (onSelectionChanged == null) {
      return;
    }
    onSelectionChanged!(TextSelection.collapsed(offset: offset));
  }
}

class WrappedEditableSurface extends StatelessWidget {
  const WrappedEditableSurface({
    super.key,
    required this.segments,
    required this.previewTextStyle,
    required this.exclusionBands,
    required this.isEditing,
    required this.focusNode,
    required this.controller,
    required this.hintText,
    required this.onActivate,
    required this.onChanged,
    required this.onSelectionChanged,
    this.onInlineMathTap,
    this.onClose,
    this.textStyle,
  });

  final List<TextSegment> segments;
  final TextStyle previewTextStyle;
  final List<FlowExclusionBand> exclusionBands;
  final bool isEditing;
  final FocusNode focusNode;
  final SegmentedTextEditingController controller;
  final String hintText;
  final VoidCallback onActivate;
  final VoidCallback onChanged;
  final ValueChanged<TextSelection> onSelectionChanged;
  final ValueChanged<int>? onInlineMathTap;
  final VoidCallback? onClose;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final borderColor = isEditing
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onActivate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isEditing ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WrappedParagraphPreview(
                segments: segments,
                textStyle: previewTextStyle,
                exclusionBands: exclusionBands,
                selection: controller.selection,
                showCaret: isEditing,
                onSelectionChanged: (selection) {
                  controller.selection = selection;
                  onSelectionChanged(selection);
                  onActivate();
                },
                onInlineMathTap: onInlineMathTap,
              ),
              if (isEditing) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editing wrapped content',
                        style: Theme.of(context).textTheme.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                Text(
                  'Tap between tokens to move the caret. Type with the keyboard to edit here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: Focus(
                      focusNode: focusNode,
                      child: TextField(
                        controller: controller,
                        style: textStyle,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: hintText,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: onActivate,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WrappedPreviewToken {
  const _WrappedPreviewToken({
    required this.value,
    required this.isMath,
    required this.startOffset,
    required this.endOffset,
    this.segmentIndex,
  });

  final String value;
  final bool isMath;
  final int startOffset;
  final int endOffset;
  final int? segmentIndex;
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
  var offset = 0;
  for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
    final segment = segments[segmentIndex];
    if (segment.isInlineMath) {
      tokens.add(
        _WrappedPreviewToken(
          value: segment.inlineMathLatex!,
          isMath: true,
          startOffset: offset,
          endOffset: offset + 1,
          segmentIndex: segmentIndex,
        ),
      );
      offset += 1;
      if (segmentIndex != segments.length - 1) {
        tokens.add(
          _WrappedPreviewToken(
            value: ' ',
            isMath: false,
            startOffset: offset,
            endOffset: offset + 1,
          ),
        );
        offset += 1;
      }
      continue;
    }
    final matches = RegExp(r'\S+\s*').allMatches(segment.text);
    if (matches.isEmpty && segment.text.isNotEmpty) {
      tokens.add(
        _WrappedPreviewToken(
          value: segment.text,
          isMath: false,
          startOffset: offset,
          endOffset: offset + segment.text.length,
        ),
      );
      offset += segment.text.length;
      continue;
    }
    for (final match in matches) {
      final value = match.group(0)!;
      tokens.add(
        _WrappedPreviewToken(
          value: value,
          isMath: false,
          startOffset: offset,
          endOffset: offset + value.length,
        ),
      );
      offset += value.length;
    }
  }
  return tokens;
}
