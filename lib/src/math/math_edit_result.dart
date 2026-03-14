import 'package:rich_text_editor/src/document/nodes/math_node.dart';

class MathEditResult {
  const MathEditResult({required this.latex, required this.displayMode});

  final String latex;
  final MathDisplayMode displayMode;
}
