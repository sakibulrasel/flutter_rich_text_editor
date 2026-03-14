import 'dart:convert';

import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';
import 'package:rich_text_editor/src/document/nodes/text_block_node.dart';

class EditorDocument {
  EditorDocument({required List<EditorNode> nodes})
      : nodes = List<EditorNode>.unmodifiable(nodes);

  factory EditorDocument.empty() {
    return EditorDocument(
      nodes: const [
        TextBlockNode(
          id: 'node_0',
          style: TextBlockStyle.paragraph,
          segments: [TextSegment(text: '')],
        ),
      ],
    );
  }

  final List<EditorNode> nodes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': 1,
      'nodes': nodes.map((node) => node.toJson()).toList(),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory EditorDocument.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List<dynamic>? ?? const [];
    return EditorDocument(
      nodes: rawNodes
          .map((node) => EditorNode.fromJson(node as Map<String, dynamic>))
          .toList(),
    );
  }

  factory EditorDocument.fromJsonString(String source) {
    return EditorDocument.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  EditorDocument copyWith({List<EditorNode>? nodes}) {
    return EditorDocument(nodes: nodes ?? this.nodes);
  }
}
