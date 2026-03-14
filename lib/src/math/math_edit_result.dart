import 'package:rich_text_editor/src/document/nodes/math_node.dart';

class MathEditResult {
  const MathEditResult({
    required this.latex,
    required this.displayMode,
  }) : delete = false;

  const MathEditResult.delete({
    required this.displayMode,
  })  : latex = '',
        delete = true;

  final String latex;
  final MathDisplayMode displayMode;
  final bool delete;
}
