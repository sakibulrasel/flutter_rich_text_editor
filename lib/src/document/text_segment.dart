import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class TextSegment {
  static const String inlineMathPlaceholder = '\uFFFC';

  const TextSegment({
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.link,
    this.inlineMathLatex,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? link;
  final String? inlineMathLatex;

  bool get hasLink => link != null && link!.isNotEmpty;

  bool get isInlineMath =>
      inlineMathLatex != null && inlineMathLatex!.isNotEmpty;

  int get plainTextLength => isInlineMath ? 1 : text.length;

  String get plainText => isInlineMath ? inlineMathPlaceholder : text;

  TextSegment copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? underline,
    String? link,
    String? inlineMathLatex,
    bool clearLink = false,
  }) {
    return TextSegment(
      text: text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      link: clearLink ? null : (link ?? this.link),
      inlineMathLatex: inlineMathLatex ?? this.inlineMathLatex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'link': link,
      'inlineMathLatex': inlineMathLatex,
    };
  }

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      text: json['text'] as String? ?? '',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      link: json['link'] as String?,
      inlineMathLatex: json['inlineMathLatex'] as String?,
    );
  }

  TextStyle applyTo(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: hasLink ? const Color(0xFF0A66C2) : null,
      decoration: _decoration,
    );
  }

  InlineSpan toInlineSpan(
    TextStyle? base, {
    VoidCallback? onTap,
  }) {
    if (isInlineMath) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              inlineMathLatex!,
              mathStyle: MathStyle.text,
              onErrorFallback: (error) {
                return Text(
                  'Invalid LaTeX',
                  style: TextStyle(color: (base ?? const TextStyle()).color),
                );
              },
            ),
          ),
        ),
      );
    }

    return TextSpan(
      text: text,
      style: applyTo(base),
      mouseCursor: onTap != null ? SystemMouseCursors.click : null,
      recognizer:
          onTap == null ? null : (TapGestureRecognizer()..onTap = onTap),
    );
  }

  TextDecoration? get _decoration {
    final decorations = <TextDecoration>[
      if (hasLink) TextDecoration.underline,
      if (underline) TextDecoration.underline,
    ];
    if (decorations.isEmpty) {
      return null;
    }
    if (decorations.length == 1) {
      return decorations.first;
    }
    return TextDecoration.combine(decorations);
  }
}
