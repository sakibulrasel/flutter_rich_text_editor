import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';

enum ListStyle {
  unordered,
  ordered,
}

class ListNode extends EditorNode {
  const ListNode({
    required super.id,
    required this.items,
    required this.style,
  });

  static const String nodeType = 'list';

  final List<List<TextSegment>> items;
  final ListStyle style;

  List<String> get plainTextItems => items
      .map((item) => item.map((segment) => segment.plainText).join())
      .toList();

  @override
  String get type => nodeType;

  ListNode copyWith({
    String? id,
    List<List<TextSegment>>? items,
    ListStyle? style,
  }) {
    return ListNode(
      id: id ?? this.id,
      items: List<List<TextSegment>>.unmodifiable(
        (items ?? this.items)
            .map((item) => List<TextSegment>.unmodifiable(item))
            .toList(),
      ),
      style: style ?? this.style,
    );
  }

  factory ListNode.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return ListNode(
      id: json['id'] as String,
      items: rawItems.map((item) {
        if (item is String) {
          return <TextSegment>[TextSegment(text: item)];
        }
        return ((item as List<dynamic>?) ?? const [])
            .map((segment) =>
                TextSegment.fromJson(segment as Map<String, dynamic>))
            .toList();
      }).toList(),
      style: ListStyle.values.byName(json['style'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'items': items
          .map((item) => item.map((segment) => segment.toJson()).toList())
          .toList(),
      'style': style.name,
    };
  }
}
