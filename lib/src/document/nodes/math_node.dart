import 'package:rich_text_editor/src/document/editor_node.dart';

enum MathDisplayMode { inline, block }

class MathNode extends EditorNode {
  const MathNode({
    required super.id,
    required this.latex,
    required this.displayMode,
  });

  static const String nodeType = 'math';

  final String latex;
  final MathDisplayMode displayMode;

  bool get isInline => displayMode == MathDisplayMode.inline;

  @override
  String get type => nodeType;

  MathNode copyWith({String? id, String? latex, MathDisplayMode? displayMode}) {
    return MathNode(
      id: id ?? this.id,
      latex: latex ?? this.latex,
      displayMode: displayMode ?? this.displayMode,
    );
  }

  factory MathNode.fromJson(Map<String, dynamic> json) {
    return MathNode(
      id: json['id'] as String,
      latex: json['latex'] as String? ?? '',
      displayMode: MathDisplayMode.values.byName(json['displayMode'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'latex': latex,
      'displayMode': displayMode.name,
    };
  }
}
