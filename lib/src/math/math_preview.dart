import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:rich_text_editor/src/document/nodes/math_node.dart';

class MathPreview extends StatelessWidget {
  const MathPreview({
    super.key,
    required this.latex,
    required this.displayMode,
  });

  final String latex;
  final MathDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final trimmed = latex.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Math.tex(
          trimmed,
          mathStyle: displayMode == MathDisplayMode.inline
              ? MathStyle.text
              : MathStyle.display,
          onErrorFallback: (error) {
            return Text(
              'Invalid LaTeX: ${error.message}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          },
        ),
      ),
    );
  }
}
