import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';

enum TextBlockStyle { paragraph, heading1, heading2 }

class TextBlockNode extends EditorNode {
  const TextBlockNode({
    required super.id,
    required this.style,
    required this.segments,
  });

  static const String nodeType = 'textBlock';

  final TextBlockStyle style;
  final List<TextSegment> segments;

  String get text => segments.map((segment) => segment.text).join();

  String get plainText => segments.map((segment) => segment.plainText).join();

  @override
  String get type => nodeType;

  TextBlockNode copyWith({
    String? id,
    TextBlockStyle? style,
    String? text,
    List<TextSegment>? segments,
  }) {
    return TextBlockNode(
      id: id ?? this.id,
      style: style ?? this.style,
      segments: List<TextSegment>.unmodifiable(
        segments ??
            (text != null
                ? <TextSegment>[TextSegment(text: text)]
                : this.segments),
      ),
    );
  }

  factory TextBlockNode.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'] as List<dynamic>?;
    return TextBlockNode(
      id: json['id'] as String,
      style: TextBlockStyle.values.byName(json['style'] as String),
      segments: List<TextSegment>.unmodifiable(
        rawSegments == null
            ? <TextSegment>[TextSegment(text: json['text'] as String? ?? '')]
            : rawSegments
                .map(
                  (segment) =>
                      TextSegment.fromJson(segment as Map<String, dynamic>),
                )
                .toList(),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'style': style.name,
      'text': text,
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }
}
