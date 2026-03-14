import 'package:flutter/material.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';

class SegmentedTextEditingController extends TextEditingController {
  SegmentedTextEditingController({
    required List<TextSegment> segments,
    this.baseStyle,
    this.onInlineMathTap,
  })  : _segments = List<TextSegment>.unmodifiable(segments),
        super(text: segments.map((segment) => segment.plainText).join());

  List<TextSegment> _segments;
  final TextStyle? baseStyle;
  final ValueChanged<int>? onInlineMathTap;

  void updateSegments(
    List<TextSegment> segments, {
    TextSelection? preferredSelection,
  }) {
    _segments = List<TextSegment>.unmodifiable(segments);
    final nextText = segments.map((segment) => segment.plainText).join();
    if (nextText != text) {
      final nextSelection =
          preferredSelection != null && preferredSelection.isValid
              ? TextSelection(
                  baseOffset:
                      preferredSelection.baseOffset.clamp(0, nextText.length),
                  extentOffset:
                      preferredSelection.extentOffset.clamp(0, nextText.length),
                )
              : selection.isValid
                  ? TextSelection.collapsed(
                      offset: selection.extentOffset.clamp(0, nextText.length),
                    )
                  : TextSelection.collapsed(offset: nextText.length);
      value = value.copyWith(
        text: nextText,
        selection: nextSelection,
        composing: TextRange.empty,
      );
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final mergedBaseStyle =
        baseStyle ?? style ?? DefaultTextStyle.of(context).style;
    final segmentText = _segments.map((segment) => segment.plainText).join();
    if (segmentText != text) {
      return TextSpan(text: text, style: mergedBaseStyle);
    }

    return TextSpan(
      style: mergedBaseStyle,
      children: [
        for (var i = 0; i < _segments.length; i++)
          _segments[i].toInlineSpan(
            mergedBaseStyle,
            onTap: _segments[i].isInlineMath && onInlineMathTap != null
                ? () => onInlineMathTap!(i)
                : null,
          ),
      ],
    );
  }
}
