import 'package:rich_text_editor/src/document/nodes/image_node.dart';
import 'package:rich_text_editor/src/document/nodes/list_node.dart';
import 'package:rich_text_editor/src/document/nodes/math_node.dart';
import 'package:rich_text_editor/src/document/nodes/text_block_node.dart';

abstract class EditorNode {
  const EditorNode({required this.id});

  final String id;

  String get type;

  Map<String, dynamic> toJson();

  static EditorNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case TextBlockNode.nodeType:
        return TextBlockNode.fromJson(json);
      case ListNode.nodeType:
        return ListNode.fromJson(json);
      case ImageNode.nodeType:
        return ImageNode.fromJson(json);
      case MathNode.nodeType:
        return MathNode.fromJson(json);
      default:
        throw UnsupportedError('Unsupported editor node type: $type');
    }
  }
}
