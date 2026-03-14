import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rich_text_editor/src/document/nodes/math_node.dart';
import 'package:rich_text_editor/src/math/math_edit_result.dart';
import 'package:rich_text_editor/src/math/math_preview.dart';
import 'package:rich_text_editor/src/math/math_templates.dart';
import 'package:rich_text_editor/src/math/math_visual_composers.dart';

Future<MathEditResult?> showMathDialog(
  BuildContext context, {
  String initialLatex = r'\frac{a}{b}',
  MathDisplayMode initialDisplayMode = MathDisplayMode.block,
}) {
  return showDialog<MathEditResult>(
    context: context,
    builder: (context) {
      return _MathDialog(
        initialLatex: initialLatex,
        initialDisplayMode: initialDisplayMode,
      );
    },
  );
}

Future<String?> _showMathSlotDialog(
  BuildContext context, {
  String initialLatex = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ExpressionEditorDialog(initialLatex: initialLatex),
  );
}

String _categoryPreviewLatex(MathCategory category) {
  return switch (category) {
    MathCategory.plainText => r'a+b',
    MathCategory.fractions => r'\frac{a}{b}',
    MathCategory.scripts => r'x^{2}',
    MathCategory.roots => r'\sqrt{x}',
    MathCategory.calculus => r'\int_{0}^{1} x \, dx',
    MathCategory.matrices => r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}',
    MathCategory.symbols => r'\alpha',
  };
}

class _MathDialog extends StatefulWidget {
  const _MathDialog({
    required this.initialLatex,
    required this.initialDisplayMode,
  });

  final String initialLatex;
  final MathDisplayMode initialDisplayMode;

  @override
  State<_MathDialog> createState() => _MathDialogState();
}

class _MathDialogState extends State<_MathDialog> {
  late MathDisplayMode _displayMode;
  late MathCategory _category;
  late MathTemplate _template;
  late List<TextEditingController> _fieldControllers;
  int _activeFieldIndex = 0;
  bool _showAdvancedSource = false;
  late final TextEditingController _advancedController;
  bool _isStructured = true;
  bool _isPlainTextMode = false;

  @override
  void initState() {
    super.initState();
    _displayMode = widget.initialDisplayMode;
    _advancedController = TextEditingController(text: widget.initialLatex);

    final parsed = parseMathTemplate(widget.initialLatex);
    if (parsed != null) {
      _category = parsed.template.category;
      _template = parsed.template;
      _fieldControllers = _buildFieldControllers(parsed.values);
    } else {
      final parsedNodes = _parseExprNodes(widget.initialLatex.trim());
      final isPlainTextOnly = parsedNodes.isNotEmpty &&
          parsedNodes.every((node) => node is _TextExprNode);
      _category =
          isPlainTextOnly ? MathCategory.plainText : MathCategory.fractions;
      _template = isPlainTextOnly
          ? kMathTemplates
              .firstWhere((template) => template.id == 'plain_expression')
          : kMathTemplates.first;
      _fieldControllers = _buildFieldControllers(_template.defaults);
      _isPlainTextMode = isPlainTextOnly;
      _isStructured = isPlainTextOnly;
      _showAdvancedSource = !isPlainTextOnly;
    }
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    _advancedController.dispose();
    super.dispose();
  }

  String get _composedLatex {
    if (_isPlainTextMode) {
      return _advancedController.text.trim();
    }
    if (!_isStructured && _showAdvancedSource) {
      return _advancedController.text.trim();
    }
    return _template.buildLatex(
      _fieldControllers.map((controller) => controller.text.trim()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Math Composer'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<MathDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: MathDisplayMode.inline,
                    label: Text('Inline'),
                  ),
                  ButtonSegment(
                    value: MathDisplayMode.block,
                    label: Text('Standalone'),
                  ),
                ],
                selected: <MathDisplayMode>{_displayMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _displayMode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in kMathCategoryLabels.entries)
                    ChoiceChip(
                      label: SizedBox(
                        width: 42,
                        height: 24,
                        child: Center(
                          child: CompactMathInline(
                            latex: _categoryPreviewLatex(entry.key),
                          ),
                        ),
                      ),
                      tooltip: entry.value,
                      selected: _category == entry.key,
                      onSelected: (_) {
                        setState(() {
                          _category = entry.key;
                          _isPlainTextMode =
                              entry.key == MathCategory.plainText;
                          _selectTemplate(
                            kMathTemplates.firstWhere(
                              (template) => template.category == entry.key,
                            ),
                          );
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in kMathTemplates.where(
                    (template) => template.category == _category,
                  ))
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isPlainTextMode = template.id == 'plain_expression';
                          _selectTemplate(template);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: template.id == _template.id
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 80,
                          minHeight: 28,
                        ),
                        child: Center(
                          child: CompactMathInline(
                            latex: template.buildLatex(template.defaults),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Fill the formula slots',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_isPlainTextMode)
                MathTemplateFieldSlot(
                  label: 'Expression',
                  latex: _advancedController.text.trim(),
                  selected: true,
                  onTap: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _advancedController.text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _advancedController.text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'fraction')
                MathFractionVisualComposer(
                  numeratorLatex: _fieldControllers[0].text.trim(),
                  denominatorLatex: _fieldControllers[1].text.trim(),
                  onEditNumerator: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditDenominator: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'power')
                MathPowerVisualComposer(
                  baseLatex: _fieldControllers[0].text.trim(),
                  exponentLatex: _fieldControllers[1].text.trim(),
                  onEditBase: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditExponent: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'subscript')
                MathSubscriptVisualComposer(
                  baseLatex: _fieldControllers[0].text.trim(),
                  subscriptLatex: _fieldControllers[1].text.trim(),
                  onEditBase: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditSubscript: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'square_root')
                MathRootVisualComposer(
                  radicandLatex: _fieldControllers[0].text.trim(),
                  onEditRadicand: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'nth_root')
                MathNthRootVisualComposer(
                  indexLatex: _fieldControllers[0].text.trim(),
                  radicandLatex: _fieldControllers[1].text.trim(),
                  onEditIndex: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditRadicand: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'integral')
                MathIntegralVisualComposer(
                  lowerLatex: _fieldControllers[0].text.trim(),
                  upperLatex: _fieldControllers[1].text.trim(),
                  expressionLatex: _fieldControllers[2].text.trim(),
                  variableLatex: _fieldControllers[3].text.trim(),
                  onEditLower: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditUpper: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                  onEditExpression: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[2].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[2].text = result;
                    setState(() {});
                  },
                  onEditVariable: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[3].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[3].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'summation')
                MathSummationVisualComposer(
                  lowerLatex: _fieldControllers[0].text.trim(),
                  upperLatex: _fieldControllers[1].text.trim(),
                  expressionLatex: _fieldControllers[2].text.trim(),
                  onEditLower: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[0].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[0].text = result;
                    setState(() {});
                  },
                  onEditUpper: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[1].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[1].text = result;
                    setState(() {});
                  },
                  onEditExpression: () async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[2].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[2].text = result;
                    setState(() {});
                  },
                )
              else if (_template.id == 'matrix_2x2')
                MathMatrixVisualComposer(
                  values: _fieldControllers
                      .map((controller) => controller.text.trim())
                      .toList(),
                  onEditCell: (index) async {
                    final result = await _showMathSlotDialog(
                      context,
                      initialLatex: _fieldControllers[index].text.trim(),
                    );
                    if (result == null) {
                      return;
                    }
                    _fieldControllers[index].text = result;
                    setState(() {});
                  },
                )
              else if (_template.fields.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This symbol does not need extra input.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < _template.fields.length; i++)
                      SizedBox(
                        width: 190,
                        child: MathTemplateFieldSlot(
                          label: _template.fields[i].label,
                          latex: _fieldControllers[i].text.trim(),
                          selected: i == _activeFieldIndex,
                          onTap: () async {
                            setState(() {
                              _activeFieldIndex = i;
                            });
                            final result = await _showMathSlotDialog(
                              context,
                              initialLatex: _fieldControllers[i].text.trim(),
                            );
                            if (result == null) {
                              return;
                            }
                            _fieldControllers[i].text = result;
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Symbols',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final symbol in kMathSymbolPalette)
                    OutlinedButton(
                      onPressed: _template.fields.isEmpty
                          ? null
                          : () {
                              final controller =
                                  _fieldControllers[_activeFieldIndex];
                              final replacement =
                                  symbol == r'\sqrt{}' ? r'\sqrt{x}' : symbol;
                              controller.text =
                                  '${controller.text.trim()}$replacement';
                              setState(() {});
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: const Size(40, 32),
                      ),
                      child: SizedBox(
                        width: 28,
                        height: 20,
                        child: Center(
                          child: CompactMathInline(
                            latex: symbol == r'\sqrt{}' ? r'\sqrt{x}' : symbol,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Preview',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              MathPreview(
                latex: _composedLatex,
                displayMode: _displayMode,
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                initiallyExpanded: _showAdvancedSource,
                title: const Text('Advanced source'),
                subtitle: Text(
                  _isStructured
                      ? 'Hidden by default. Internal storage still uses LaTeX.'
                      : 'This formula could not be mapped to a visual template yet.',
                ),
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showAdvancedSource = expanded;
                  });
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _advancedController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Formula source',
                      ),
                      onChanged: (_) {
                        setState(() {
                          _isStructured = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _composedLatex.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    MathEditResult(
                      latex: _composedLatex,
                      displayMode: _displayMode,
                    ),
                  );
                },
          child: const Text('Insert'),
        ),
      ],
    );
  }

  void _selectTemplate(MathTemplate template) {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    _template = template;
    _fieldControllers = _buildFieldControllers(template.defaults);
    _activeFieldIndex = 0;
    _isPlainTextMode = false;
    _isStructured = true;
    _advancedController.text = template.buildLatex(template.defaults);
  }

  List<TextEditingController> _buildFieldControllers(List<String> values) {
    return values.map((value) => TextEditingController(text: value)).toList();
  }
}

abstract class _ExprNode {
  const _ExprNode();

  String toLatex();
}

class _TextExprNode extends _ExprNode {
  const _TextExprNode(this.text);

  final String text;

  @override
  String toLatex() => text;
}

class _LatexExprNode extends _ExprNode {
  const _LatexExprNode(this.latex);

  final String latex;

  @override
  String toLatex() => latex;
}

class _FractionExprNode extends _ExprNode {
  const _FractionExprNode({
    required this.numerator,
    required this.denominator,
  });

  final List<_ExprNode> numerator;
  final List<_ExprNode> denominator;

  @override
  String toLatex() {
    return '\\frac{${_exprNodesToLatex(numerator)}}{${_exprNodesToLatex(denominator)}}';
  }
}

String _exprNodesToLatex(List<_ExprNode> nodes) {
  return nodes.map((node) => node.toLatex()).join();
}

List<_ExprNode> _tokenizePlainText(String input) {
  final nodes = <_ExprNode>[];
  final expression = RegExp(
    r'(\\[A-Za-z]+|[A-Za-z0-9]|[\+\-\*/=\(\)\[\]]|\s+|.)',
  );
  for (final match in expression.allMatches(input)) {
    final token = match.group(0);
    if (token == null || token.isEmpty) {
      continue;
    }
    nodes.add(_TextExprNode(token));
  }
  return nodes;
}

List<_ExprNode> _parseExprNodes(String latex) {
  final nodes = <_ExprNode>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushBuffer() {
    if (buffer.isNotEmpty) {
      nodes.addAll(_tokenizePlainText(buffer.toString()));
      buffer.clear();
    }
  }

  while (index < latex.length) {
    if (latex.startsWith(r'\frac{', index)) {
      flushBuffer();
      index += r'\frac'.length;
      final numeratorGroup = _readBraceGroup(latex, index);
      if (numeratorGroup == null) {
        buffer.write(latex.substring(index));
        break;
      }
      index = numeratorGroup.nextIndex;
      final denominatorGroup = _readBraceGroup(latex, index);
      if (denominatorGroup == null) {
        buffer.write(latex.substring(index));
        break;
      }
      index = denominatorGroup.nextIndex;
      nodes.add(
        _FractionExprNode(
          numerator: _parseExprNodes(numeratorGroup.content),
          denominator: _parseExprNodes(denominatorGroup.content),
        ),
      );
      continue;
    }

    buffer.write(latex[index]);
    index++;
  }

  flushBuffer();
  return nodes;
}

class _BraceGroup {
  const _BraceGroup({
    required this.content,
    required this.nextIndex,
  });

  final String content;
  final int nextIndex;
}

_BraceGroup? _readBraceGroup(String value, int startIndex) {
  if (startIndex >= value.length || value[startIndex] != '{') {
    return null;
  }

  final buffer = StringBuffer();
  var depth = 0;
  for (var i = startIndex; i < value.length; i++) {
    final char = value[i];
    if (char == '{') {
      if (depth > 0) {
        buffer.write(char);
      }
      depth++;
      continue;
    }
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return _BraceGroup(content: buffer.toString(), nextIndex: i + 1);
      }
      buffer.write(char);
      continue;
    }
    buffer.write(char);
  }
  return null;
}

class _ExpressionEditorDialog extends StatefulWidget {
  const _ExpressionEditorDialog({
    required this.initialLatex,
  });

  final String initialLatex;

  @override
  State<_ExpressionEditorDialog> createState() =>
      _ExpressionEditorDialogState();
}

class _ExpressionEditorDialogState extends State<_ExpressionEditorDialog> {
  late List<_ExprNode> _nodes;
  int? _selectedIndex;
  late int _caretIndex;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _nodes = widget.initialLatex.trim().isEmpty
        ? <_ExprNode>[]
        : _parseExprNodes(widget.initialLatex.trim());
    _selectedIndex = null;
    _caretIndex = _nodes.length;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Formula'),
      content: SizedBox(
        width: 760,
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (_, event) => _handleKeyEvent(event),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit the whole expression or select a token and insert structured formulas into it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _ExpressionCanvas(
                  nodes: _nodes,
                  selectedIndex: _selectedIndex,
                  caretIndex: _caretIndex,
                  onSelectNode: (index) {
                    setState(() {
                      _selectedIndex = index;
                      _caretIndex = index + 1;
                    });
                  },
                  onMoveCaret: (index) {
                    setState(() {
                      _selectedIndex = null;
                      _caretIndex = index;
                    });
                  },
                  onEditFraction: (index) async {
                    final node = _nodes[index];
                    if (node is! _FractionExprNode) {
                      return;
                    }
                    final result = await _showFractionNodeDialog(
                      context,
                      initialNode: node,
                    );
                    if (result == null) {
                      return;
                    }
                    setState(() {
                      _nodes[index] = result;
                      _selectedIndex = index;
                      _caretIndex = index + 1;
                    });
                  },
                  onEditText: (index) async {
                    final node = _nodes[index];
                    if (node is! _TextExprNode) {
                      return;
                    }
                    final result = await _showTextTokenDialog(
                      context,
                      initialText: node.text,
                    );
                    if (result == null) {
                      return;
                    }
                    setState(() {
                      _nodes
                        ..removeAt(index)
                        ..insertAll(index, _tokenizePlainText(result));
                      _selectedIndex = null;
                      _caretIndex = index + _tokenizePlainText(result).length;
                    });
                  },
                  onEditLatex: (index) async {
                    final node = _nodes[index];
                    if (node is! _LatexExprNode) {
                      return;
                    }
                    final result = await _showTemplateExprNodeDialog(
                      context,
                      initialLatex: node.latex,
                    );
                    if (result == null) {
                      return;
                    }
                    setState(() {
                      _nodes[index] = result;
                      _selectedIndex = index;
                      _caretIndex = index + 1;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () async {
                        final selectedNode = _selectedIndex != null
                            ? _nodes[_selectedIndex!]
                            : null;
                        final result = await _showTextTokenDialog(
                          context,
                          initialText: selectedNode is _TextExprNode
                              ? selectedNode.text
                              : _exprNodesToLatex(_nodes),
                        );
                        if (result == null) {
                          return;
                        }
                        setState(() {
                          if (selectedNode is _TextExprNode &&
                              _selectedIndex != null) {
                            final index = _selectedIndex!;
                            final replacementNodes = _tokenizePlainText(result);
                            _nodes
                              ..removeAt(index)
                              ..insertAll(index, replacementNodes);
                            _selectedIndex = null;
                            _caretIndex = index + replacementNodes.length;
                            _applyAutoConversionsNearCaret();
                          } else {
                            _nodes = _parseExprNodes(result);
                            _selectedIndex = null;
                            _caretIndex = _nodes.length;
                            _applyAutoConversionsNearCaret();
                          }
                        });
                      },
                      child: const Text('Edit Expression'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final result = await _showTextTokenDialog(
                          context,
                          initialText: _exprNodesToLatex(_nodes),
                        );
                        if (result == null) {
                          return;
                        }
                        setState(() {
                          _nodes = _parseExprNodes(result);
                          _selectedIndex = null;
                          _caretIndex = _nodes.length;
                          _applyAutoConversionsNearCaret();
                        });
                      },
                      child: const Text('Edit All'),
                    ),
                    if (_selectedIndex != null)
                      FilledButton.tonal(
                        onPressed: () async {
                          final index = _selectedIndex!;
                          final node = _nodes[index];
                          if (node is _TextExprNode) {
                            final result = await _showTextTokenDialog(
                              context,
                              initialText: node.text,
                            );
                            if (result == null) {
                              return;
                            }
                            setState(() {
                              final replacementNodes =
                                  _tokenizePlainText(result);
                              _nodes
                                ..removeAt(index)
                                ..insertAll(index, replacementNodes);
                              _selectedIndex = null;
                              _caretIndex = index + replacementNodes.length;
                              _applyAutoConversionsNearCaret();
                            });
                          } else if (node is _LatexExprNode) {
                            final result = await _showTemplateExprNodeDialog(
                              context,
                              initialLatex: node.latex,
                            );
                            if (result == null) {
                              return;
                            }
                            setState(() {
                              _nodes[index] = result;
                              _selectedIndex = index;
                              _caretIndex = index + 1;
                            });
                          } else if (node is _FractionExprNode) {
                            final result = await _showFractionNodeDialog(
                              context,
                              initialNode: node,
                            );
                            if (result == null) {
                              return;
                            }
                            setState(() {
                              _nodes[index] = result;
                              _selectedIndex = index;
                              _caretIndex = index + 1;
                            });
                          }
                        },
                        child: const Text('Edit Selected'),
                      ),
                    FilledButton.tonal(
                      onPressed: () async {
                        final text = await _showTextTokenDialog(context);
                        if (text == null || text.isEmpty) {
                          return;
                        }
                        setState(() {
                          _insertNodes(_tokenizePlainText(text));
                        });
                      },
                      child: const Text('Add Expression'),
                    ),
                    if (_canConvertSlashToFraction)
                      FilledButton.tonal(
                        onPressed: () {
                          setState(_convertSlashToFraction);
                        },
                        child: const Text('Make Fraction'),
                      ),
                    if (_canConvertCaretToPower)
                      FilledButton.tonal(
                        onPressed: () {
                          setState(_convertCaretToPower);
                        },
                        child: const Text('Make Power'),
                      ),
                    if (_canConvertUnderscoreToSubscript)
                      FilledButton.tonal(
                        onPressed: () {
                          setState(_convertUnderscoreToSubscript);
                        },
                        child: const Text('Make Subscript'),
                      ),
                    for (final template in kMathTemplates)
                      _TemplateInsertButton(
                        template: template,
                        onPressed: () async {
                          final node = await _showTemplateExprNodeDialog(
                            context,
                            initialLatex:
                                template.buildLatex(template.defaults),
                            forcedTemplate: template,
                          );
                          if (node == null) {
                            return;
                          }
                          setState(() {
                            _insertNode(node);
                          });
                        },
                      ),
                    if (_selectedIndex != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _nodes.removeAt(_selectedIndex!);
                            _caretIndex = _selectedIndex!;
                            _selectedIndex = _nodes.isEmpty
                                ? null
                                : (_selectedIndex! - 1)
                                    .clamp(0, _nodes.length - 1);
                          });
                        },
                        child: const Text('Delete Selected'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_hasAutoConversionSuggestions) ...[
                  Text(
                    'Suggestions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_chemicalPattern != null)
                        ActionChip(
                          label: const Text('Convert chemical formula'),
                          onPressed: () {
                            setState(_convertChemicalPattern);
                          },
                        ),
                      if (_sqrtPatternStart != null)
                        ActionChip(
                          label: const Text('Convert to square root'),
                          onPressed: () {
                            setState(_convertSqrtPattern);
                          },
                        ),
                      if (_nthRootPattern != null)
                        ActionChip(
                          label: const Text('Convert to nth root'),
                          onPressed: () {
                            setState(_convertNthRootPattern);
                          },
                        ),
                      if (_arrowPattern != null)
                        ActionChip(
                          label: const Text('Convert reaction arrow'),
                          onPressed: () {
                            setState(_convertArrowPattern);
                          },
                        ),
                      if (_canConvertSlashToFraction)
                        ActionChip(
                          label: const Text('Convert to fraction'),
                          onPressed: () {
                            setState(_convertSlashToFraction);
                          },
                        ),
                      if (_canConvertCaretToPower)
                        ActionChip(
                          label: const Text('Convert to power'),
                          onPressed: () {
                            setState(_convertCaretToPower);
                          },
                        ),
                      if (_canConvertUnderscoreToSubscript)
                        ActionChip(
                          label: const Text('Convert to subscript'),
                          onPressed: () {
                            setState(_convertUnderscoreToSubscript);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                MathPreview(
                  latex: _exprNodesToLatex(_nodes),
                  displayMode: MathDisplayMode.inline,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_exprNodesToLatex(_nodes)),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _insertNode(_ExprNode node) {
    _nodes.insert(_caretIndex, node);
    _selectedIndex = _caretIndex;
    _caretIndex += 1;
    _normalizeNodes();
  }

  void _insertNodes(List<_ExprNode> newNodes) {
    if (newNodes.isEmpty) {
      return;
    }
    _nodes.insertAll(_caretIndex, newNodes);
    _selectedIndex = null;
    _caretIndex += newNodes.length;
    _normalizeNodes();
    _applyAutoConversionsNearCaret();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(_moveCaretLeft);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(_moveCaretRight);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      setState(_backspaceAtCaret);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      setState(_deleteAtCaret);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveCaretLeft() {
    if (_selectedIndex != null) {
      _caretIndex = _selectedIndex!;
      _selectedIndex = null;
      return;
    }
    if (_caretIndex > 0) {
      _caretIndex -= 1;
    }
  }

  void _moveCaretRight() {
    if (_selectedIndex != null) {
      _caretIndex = _selectedIndex! + 1;
      _selectedIndex = null;
      return;
    }
    if (_caretIndex < _nodes.length) {
      _caretIndex += 1;
    }
  }

  void _backspaceAtCaret() {
    if (_selectedIndex != null) {
      _nodes.removeAt(_selectedIndex!);
      _caretIndex = _selectedIndex!;
      _selectedIndex = null;
      _normalizeNodes();
      return;
    }
    if (_caretIndex == 0 || _nodes.isEmpty) {
      return;
    }
    _nodes.removeAt(_caretIndex - 1);
    _caretIndex -= 1;
    _normalizeNodes();
  }

  void _deleteAtCaret() {
    if (_selectedIndex != null) {
      _nodes.removeAt(_selectedIndex!);
      _caretIndex = _selectedIndex!;
      _selectedIndex = null;
      _normalizeNodes();
      return;
    }
    if (_caretIndex >= _nodes.length || _nodes.isEmpty) {
      return;
    }
    _nodes.removeAt(_caretIndex);
    _normalizeNodes();
  }

  void _normalizeNodes() {
    final normalized = <_ExprNode>[];
    for (final node in _nodes) {
      if (node is _TextExprNode) {
        if (node.text.isEmpty) {
          continue;
        }
        if (normalized.isNotEmpty &&
            normalized.last is _TextExprNode &&
            (normalized.last as _TextExprNode).text.trim().isEmpty &&
            node.text.trim().isEmpty) {
          final previous = normalized.removeLast() as _TextExprNode;
          normalized.add(_TextExprNode('${previous.text}${node.text}'));
          continue;
        }
        normalized.add(node);
        continue;
      }
      normalized.add(node);
    }
    _nodes = normalized;
    if (_caretIndex > _nodes.length) {
      _caretIndex = _nodes.length;
    }
  }

  bool get _canConvertSlashToFraction => _findOperatorIndex('/') != null;

  bool get _canConvertCaretToPower => _findOperatorIndex('^') != null;

  bool get _canConvertUnderscoreToSubscript => _findOperatorIndex('_') != null;

  int? get _sqrtPatternStart => _findSqrtPatternStart();

  _NthRootPattern? get _nthRootPattern => _findNthRootPattern();

  _ArrowPattern? get _arrowPattern => _findArrowPattern();

  _ChemicalPattern? get _chemicalPattern => _findChemicalPattern();

  bool get _hasAutoConversionSuggestions =>
      _chemicalPattern != null ||
      _sqrtPatternStart != null ||
      _nthRootPattern != null ||
      _arrowPattern != null ||
      _canConvertSlashToFraction ||
      _canConvertCaretToPower ||
      _canConvertUnderscoreToSubscript;

  void _applyAutoConversionsNearCaret() {
    var converted = true;
    while (converted) {
      converted = false;
      if (_chemicalPattern != null) {
        _convertChemicalPattern();
        converted = true;
        continue;
      }
      if (_nthRootPattern != null) {
        _convertNthRootPattern();
        converted = true;
        continue;
      }
      if (_sqrtPatternStart != null) {
        _convertSqrtPattern();
        converted = true;
        continue;
      }
      if (_arrowPattern != null) {
        _convertArrowPattern();
        converted = true;
        continue;
      }
      if (_canConvertSlashToFraction) {
        _convertSlashToFraction();
        converted = true;
        continue;
      }
      if (_canConvertCaretToPower) {
        _convertCaretToPower();
        converted = true;
        continue;
      }
      if (_canConvertUnderscoreToSubscript) {
        _convertUnderscoreToSubscript();
        converted = true;
      }
    }
  }

  int? _findOperatorIndex(String symbol) {
    final candidates = <int?>[];
    if (_selectedIndex != null) {
      candidates.add(_selectedIndex);
      candidates.add(_selectedIndex! - 1);
      candidates.add(_selectedIndex! + 1);
    } else {
      candidates.add(_caretIndex - 2);
      candidates.add(_caretIndex - 1);
      candidates.add(_caretIndex);
      candidates.add(_caretIndex + 1);
    }

    for (final candidate in candidates) {
      if (_isOperatorAt(candidate, symbol)) {
        return candidate;
      }
    }
    return null;
  }

  bool _isOperatorAt(int? index, String symbol) {
    if (index == null || index <= 0 || index >= _nodes.length - 1) {
      return false;
    }
    final node = _nodes[index];
    return node is _TextExprNode && node.text == symbol;
  }

  void _convertSlashToFraction() {
    final slashIndex = _findOperatorIndex('/')!;
    final leftRange = _collectOperandRangeLeft(slashIndex);
    final rightRange = _collectOperandRangeRight(slashIndex);
    final numerator = _nodes.sublist(leftRange.$1, leftRange.$2);
    final denominator = _nodes.sublist(rightRange.$1, rightRange.$2);
    _nodes.replaceRange(
      leftRange.$1,
      rightRange.$2,
      [
        _FractionExprNode(
          numerator: numerator,
          denominator: denominator,
        ),
      ],
    );
    _selectedIndex = leftRange.$1;
    _caretIndex = leftRange.$1 + 1;
    _normalizeNodes();
  }

  void _convertCaretToPower() {
    final operatorIndex = _findOperatorIndex('^')!;
    final leftRange = _collectOperandRangeLeft(operatorIndex);
    final rightRange = _collectOperandRangeRight(operatorIndex);
    final baseLatex =
        _exprNodesToLatex(_nodes.sublist(leftRange.$1, leftRange.$2));
    final exponentLatex = _exprNodesToLatex(
      _nodes.sublist(rightRange.$1, rightRange.$2),
    );
    _nodes.replaceRange(
      leftRange.$1,
      rightRange.$2,
      [
        _LatexExprNode(
          '$baseLatex^{$exponentLatex}',
        ),
      ],
    );
    _selectedIndex = leftRange.$1;
    _caretIndex = leftRange.$1 + 1;
    _normalizeNodes();
  }

  void _convertUnderscoreToSubscript() {
    final operatorIndex = _findOperatorIndex('_')!;
    final leftRange = _collectOperandRangeLeft(operatorIndex);
    final rightRange = _collectOperandRangeRight(operatorIndex);
    final baseLatex =
        _exprNodesToLatex(_nodes.sublist(leftRange.$1, leftRange.$2));
    final subscriptLatex = _exprNodesToLatex(
      _nodes.sublist(rightRange.$1, rightRange.$2),
    );
    _nodes.replaceRange(
      leftRange.$1,
      rightRange.$2,
      [
        _LatexExprNode(
          '$baseLatex' '_{$subscriptLatex}',
        ),
      ],
    );
    _selectedIndex = leftRange.$1;
    _caretIndex = leftRange.$1 + 1;
    _normalizeNodes();
  }

  (int, int) _collectOperandRangeLeft(int operatorIndex) {
    var start = operatorIndex - 1;
    while (start > 0 && _isOperandNode(_nodes[start - 1])) {
      start -= 1;
    }
    return (start, operatorIndex);
  }

  (int, int) _collectOperandRangeRight(int operatorIndex) {
    var end = operatorIndex + 2;
    while (end < _nodes.length && _isOperandNode(_nodes[end])) {
      end += 1;
    }
    return (operatorIndex + 1, end);
  }

  bool _isOperandNode(_ExprNode node) {
    if (node is _FractionExprNode || node is _LatexExprNode) {
      return true;
    }
    if (node is! _TextExprNode) {
      return false;
    }
    final text = node.text;
    if (text.trim().isEmpty) {
      return false;
    }
    return !const {'+', '-', '*', '/', '=', '^', '_', '(', ')', '[', ']'}
        .contains(text);
  }

  bool _isTextTokenAt(int index, String value) {
    if (index < 0 || index >= _nodes.length) {
      return false;
    }
    final node = _nodes[index];
    return node is _TextExprNode && node.text == value;
  }

  int? _findSqrtPatternStart() {
    for (var i = 0; i <= _nodes.length - 4; i++) {
      if (_isTextTokenAt(i, 's') &&
          _isTextTokenAt(i + 1, 'q') &&
          _isTextTokenAt(i + 2, 'r') &&
          _isTextTokenAt(i + 3, 't')) {
        final afterKeyword = i + 4;
        if (afterKeyword >= _nodes.length) {
          continue;
        }
        if (_isTextTokenAt(afterKeyword, '(')) {
          final closeIndex = _findClosingParen(afterKeyword);
          if (closeIndex != null && closeIndex > afterKeyword + 1) {
            return i;
          }
        } else if (_isOperandNode(_nodes[afterKeyword])) {
          return i;
        }
      }
    }
    return null;
  }

  void _convertSqrtPattern() {
    final start = _sqrtPatternStart!;
    final afterKeyword = start + 4;
    late final int end;
    late final String radicandLatex;
    if (_isTextTokenAt(afterKeyword, '(')) {
      final closeIndex = _findClosingParen(afterKeyword)!;
      radicandLatex = _exprNodesToLatex(
        _nodes.sublist(afterKeyword + 1, closeIndex),
      );
      end = closeIndex + 1;
    } else {
      final range = _collectOperandRangeRight(afterKeyword - 1);
      radicandLatex = _exprNodesToLatex(_nodes.sublist(range.$1, range.$2));
      end = range.$2;
    }
    _nodes.replaceRange(
      start,
      end,
      [_LatexExprNode(r'\sqrt{' '$radicandLatex' '}')],
    );
    _selectedIndex = start;
    _caretIndex = start + 1;
    _normalizeNodes();
  }

  _NthRootPattern? _findNthRootPattern() {
    for (var i = 0; i <= _nodes.length - 5; i++) {
      if (!(_isTextTokenAt(i, 'r') &&
          _isTextTokenAt(i + 1, 'o') &&
          _isTextTokenAt(i + 2, 'o') &&
          _isTextTokenAt(i + 3, 't') &&
          _isTextTokenAt(i + 4, '('))) {
        continue;
      }
      final closeIndex = _findClosingParen(i + 4);
      if (closeIndex == null) {
        continue;
      }
      final commaIndex = _findCommaBetween(i + 5, closeIndex);
      if (commaIndex == null) {
        continue;
      }
      if (commaIndex == i + 5 || commaIndex == closeIndex - 1) {
        continue;
      }
      return _NthRootPattern(
        start: i,
        commaIndex: commaIndex,
        closeIndex: closeIndex,
      );
    }
    return null;
  }

  void _convertNthRootPattern() {
    final pattern = _nthRootPattern!;
    final indexLatex = _exprNodesToLatex(
      _nodes.sublist(pattern.start + 5, pattern.commaIndex),
    );
    final radicandLatex = _exprNodesToLatex(
      _nodes.sublist(pattern.commaIndex + 1, pattern.closeIndex),
    );
    _nodes.replaceRange(
      pattern.start,
      pattern.closeIndex + 1,
      [_LatexExprNode(r'\sqrt[' '$indexLatex' ']{' '$radicandLatex' '}')],
    );
    _selectedIndex = pattern.start;
    _caretIndex = pattern.start + 1;
    _normalizeNodes();
  }

  _ArrowPattern? _findArrowPattern() {
    for (var i = 0; i < _nodes.length - 2; i++) {
      if (_isTextTokenAt(i, '<') &&
          _isTextTokenAt(i + 1, '-') &&
          _isTextTokenAt(i + 2, '>')) {
        return _ArrowPattern(
            start: i, end: i + 3, latex: r'\rightleftharpoons');
      }
    }
    for (var i = 0; i < _nodes.length - 1; i++) {
      if (_isTextTokenAt(i, '-') && _isTextTokenAt(i + 1, '>')) {
        return _ArrowPattern(start: i, end: i + 2, latex: r'\rightarrow');
      }
    }
    return null;
  }

  void _convertArrowPattern() {
    final pattern = _arrowPattern!;
    _nodes.replaceRange(
      pattern.start,
      pattern.end,
      [_LatexExprNode(pattern.latex)],
    );
    _selectedIndex = pattern.start;
    _caretIndex = pattern.start + 1;
    _normalizeNodes();
  }

  _ChemicalPattern? _findChemicalPattern() {
    final candidateStarts = <int>{
      if (_selectedIndex != null) _selectedIndex!,
      if (_selectedIndex != null) _selectedIndex! - 1,
      if (_selectedIndex != null) _selectedIndex! + 1,
      _caretIndex - 1,
      _caretIndex,
    };

    for (final candidate in candidateStarts) {
      if (candidate < 0 || candidate >= _nodes.length) {
        continue;
      }
      if (!_isChemicalTextNode(_nodes[candidate])) {
        continue;
      }
      var start = candidate;
      var end = candidate + 1;
      while (start > 0 && _isChemicalTextNode(_nodes[start - 1])) {
        start -= 1;
      }
      while (end < _nodes.length && _isChemicalTextNode(_nodes[end])) {
        end += 1;
      }
      final raw = _exprNodesToLatex(_nodes.sublist(start, end));
      if (_isChemicalFormula(raw)) {
        return _ChemicalPattern(
          start: start,
          end: end,
          latex: _buildChemicalLatex(raw),
        );
      }
    }
    return null;
  }

  void _convertChemicalPattern() {
    final pattern = _chemicalPattern!;
    _nodes.replaceRange(
      pattern.start,
      pattern.end,
      [_LatexExprNode(pattern.latex)],
    );
    _selectedIndex = pattern.start;
    _caretIndex = pattern.start + 1;
    _normalizeNodes();
  }

  int? _findClosingParen(int openParenIndex) {
    var depth = 0;
    for (var i = openParenIndex; i < _nodes.length; i++) {
      if (_isTextTokenAt(i, '(')) {
        depth += 1;
      } else if (_isTextTokenAt(i, ')')) {
        depth -= 1;
        if (depth == 0) {
          return i;
        }
      }
    }
    return null;
  }

  int? _findCommaBetween(int start, int end) {
    var depth = 0;
    for (var i = start; i < end; i++) {
      if (_isTextTokenAt(i, '(')) {
        depth += 1;
      } else if (_isTextTokenAt(i, ')')) {
        depth -= 1;
      } else if (_isTextTokenAt(i, ',') && depth == 0) {
        return i;
      }
    }
    return null;
  }

  bool _isChemicalTextNode(_ExprNode node) {
    if (node is! _TextExprNode) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9()]$').hasMatch(node.text);
  }

  bool _isChemicalFormula(String value) {
    return RegExp(r'^(?:[A-Z][a-z]?\d*|\([A-Za-z0-9]+\)\d*)+$').hasMatch(value);
  }

  String _buildChemicalLatex(String value) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < value.length) {
      final char = value[index];
      if (_isUppercase(char)) {
        buffer.write(char);
        index += 1;
        if (index < value.length && _isLowercase(value[index])) {
          buffer.write(value[index]);
          index += 1;
        }
        final digitStart = index;
        while (index < value.length && _isDigit(value[index])) {
          index += 1;
        }
        if (index > digitStart) {
          buffer.write('_{${value.substring(digitStart, index)}}');
        }
        continue;
      }
      if (char == '(') {
        final closeIndex = value.indexOf(')', index);
        if (closeIndex > index) {
          buffer.write(value.substring(index, closeIndex + 1));
          index = closeIndex + 1;
          final digitStart = index;
          while (index < value.length && _isDigit(value[index])) {
            index += 1;
          }
          if (index > digitStart) {
            buffer.write('_{${value.substring(digitStart, index)}}');
          }
          continue;
        }
      }
      buffer.write(char);
      index += 1;
    }
    return buffer.toString();
  }

  bool _isUppercase(String value) => RegExp(r'^[A-Z]$').hasMatch(value);

  bool _isLowercase(String value) => RegExp(r'^[a-z]$').hasMatch(value);

  bool _isDigit(String value) => RegExp(r'^[0-9]$').hasMatch(value);
}

class _NthRootPattern {
  const _NthRootPattern({
    required this.start,
    required this.commaIndex,
    required this.closeIndex,
  });

  final int start;
  final int commaIndex;
  final int closeIndex;
}

class _ArrowPattern {
  const _ArrowPattern({
    required this.start,
    required this.end,
    required this.latex,
  });

  final int start;
  final int end;
  final String latex;
}

class _ChemicalPattern {
  const _ChemicalPattern({
    required this.start,
    required this.end,
    required this.latex,
  });

  final int start;
  final int end;
  final String latex;
}

Future<_FractionExprNode?> _showFractionNodeDialog(
  BuildContext context, {
  _FractionExprNode? initialNode,
}) {
  return showDialog<_FractionExprNode>(
    context: context,
    builder: (context) => _FractionNodeDialog(initialNode: initialNode),
  );
}

Future<_ExprNode?> _showTemplateExprNodeDialog(
  BuildContext context, {
  String initialLatex = '',
  MathTemplate? forcedTemplate,
}) {
  if (forcedTemplate?.id == 'fraction') {
    return _showFractionNodeDialog(context);
  }

  return showDialog<_ExprNode>(
    context: context,
    builder: (context) => _TemplateExprNodeDialog(
      initialLatex: initialLatex,
      forcedTemplate: forcedTemplate,
    ),
  );
}

class _FractionNodeDialog extends StatefulWidget {
  const _FractionNodeDialog({
    this.initialNode,
  });

  final _FractionExprNode? initialNode;

  @override
  State<_FractionNodeDialog> createState() => _FractionNodeDialogState();
}

class _FractionNodeDialogState extends State<_FractionNodeDialog> {
  late List<_ExprNode> _numerator;
  late List<_ExprNode> _denominator;

  @override
  void initState() {
    super.initState();
    _numerator = widget.initialNode?.numerator.toList() ?? <_ExprNode>[];
    _denominator = widget.initialNode?.denominator.toList() ?? <_ExprNode>[];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fraction'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MathFractionVisualComposer(
              numeratorLatex: _exprNodesToLatex(_numerator),
              denominatorLatex: _exprNodesToLatex(_denominator),
              onEditNumerator: () async {
                final result = await _showMathSlotDialog(
                  context,
                  initialLatex: _exprNodesToLatex(_numerator),
                );
                if (result == null) {
                  return;
                }
                setState(() {
                  _numerator = _parseExprNodes(result);
                });
              },
              onEditDenominator: () async {
                final result = await _showMathSlotDialog(
                  context,
                  initialLatex: _exprNodesToLatex(_denominator),
                );
                if (result == null) {
                  return;
                }
                setState(() {
                  _denominator = _parseExprNodes(result);
                });
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Full Formula Preview',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            MathPreview(
              latex: _FractionExprNode(
                numerator: _numerator,
                denominator: _denominator,
              ).toLatex(),
              displayMode: MathDisplayMode.inline,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _FractionExprNode(
                numerator: _numerator,
                denominator: _denominator,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

Future<String?> _showTextTokenDialog(
  BuildContext context, {
  String initialText = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextTokenDialog(initialText: initialText),
  );
}

class _TextTokenDialog extends StatefulWidget {
  const _TextTokenDialog({
    required this.initialText,
  });

  final String initialText;

  @override
  State<_TextTokenDialog> createState() => _TextTokenDialogState();
}

class _TextTokenDialogState extends State<_TextTokenDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Text or symbols',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _TemplateExprNodeDialog extends StatefulWidget {
  const _TemplateExprNodeDialog({
    required this.initialLatex,
    this.forcedTemplate,
  });

  final String initialLatex;
  final MathTemplate? forcedTemplate;

  @override
  State<_TemplateExprNodeDialog> createState() =>
      _TemplateExprNodeDialogState();
}

class _TemplateExprNodeDialogState extends State<_TemplateExprNodeDialog> {
  late MathCategory _category;
  late MathTemplate _template;
  late List<TextEditingController> _fieldControllers;

  @override
  void initState() {
    super.initState();
    final parsed = widget.forcedTemplate == null
        ? parseMathTemplate(widget.initialLatex)
        : null;
    _template = widget.forcedTemplate ??
        parsed?.template ??
        kMathTemplates.firstWhere((t) => t.id != 'fraction');
    _category = _template.category;
    _fieldControllers = _buildFieldControllers(
      widget.forcedTemplate == null && parsed != null
          ? parsed.values
          : _template.defaults,
    );
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _latex => _template.buildLatex(
        _fieldControllers.map((controller) => controller.text.trim()).toList(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insert Formula'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.forcedTemplate == null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in kMathCategoryLabels.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _category == entry.key,
                        onSelected: (_) {
                          setState(() {
                            _category = entry.key;
                            _selectTemplate(
                              kMathTemplates.firstWhere(
                                (template) =>
                                    template.category == entry.key &&
                                    template.id != 'fraction',
                              ),
                            );
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final template in kMathTemplates.where(
                      (template) =>
                          template.category == _category &&
                          template.id != 'fraction',
                    ))
                      _TemplateInsertButton(
                        template: template,
                        onPressed: () {
                          setState(() {
                            _selectTemplate(template);
                          });
                        },
                        selected: template.id == _template.id,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_template.fields.isNotEmpty)
                if (_template.id == 'power')
                  MathPowerVisualComposer(
                    baseLatex: _fieldControllers[0].text.trim(),
                    exponentLatex: _fieldControllers[1].text.trim(),
                    onEditBase: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                    onEditExponent: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[1].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[1].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'subscript')
                  MathSubscriptVisualComposer(
                    baseLatex: _fieldControllers[0].text.trim(),
                    subscriptLatex: _fieldControllers[1].text.trim(),
                    onEditBase: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                    onEditSubscript: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[1].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[1].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'square_root')
                  MathRootVisualComposer(
                    radicandLatex: _fieldControllers[0].text.trim(),
                    onEditRadicand: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'nth_root')
                  MathNthRootVisualComposer(
                    indexLatex: _fieldControllers[0].text.trim(),
                    radicandLatex: _fieldControllers[1].text.trim(),
                    onEditIndex: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                    onEditRadicand: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[1].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[1].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'integral')
                  MathIntegralVisualComposer(
                    lowerLatex: _fieldControllers[0].text.trim(),
                    upperLatex: _fieldControllers[1].text.trim(),
                    expressionLatex: _fieldControllers[2].text.trim(),
                    variableLatex: _fieldControllers[3].text.trim(),
                    onEditLower: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                    onEditUpper: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[1].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[1].text = result;
                      setState(() {});
                    },
                    onEditExpression: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[2].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[2].text = result;
                      setState(() {});
                    },
                    onEditVariable: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[3].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[3].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'summation')
                  MathSummationVisualComposer(
                    lowerLatex: _fieldControllers[0].text.trim(),
                    upperLatex: _fieldControllers[1].text.trim(),
                    expressionLatex: _fieldControllers[2].text.trim(),
                    onEditLower: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[0].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[0].text = result;
                      setState(() {});
                    },
                    onEditUpper: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[1].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[1].text = result;
                      setState(() {});
                    },
                    onEditExpression: () async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[2].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[2].text = result;
                      setState(() {});
                    },
                  )
                else if (_template.id == 'matrix_2x2')
                  MathMatrixVisualComposer(
                    values: _fieldControllers
                        .map((controller) => controller.text.trim())
                        .toList(),
                    onEditCell: (index) async {
                      final result = await _showMathSlotDialog(
                        context,
                        initialLatex: _fieldControllers[index].text.trim(),
                      );
                      if (result == null) {
                        return;
                      }
                      _fieldControllers[index].text = result;
                      setState(() {});
                    },
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < _template.fields.length; i++)
                        SizedBox(
                          width: 180,
                          child: MathTemplateFieldSlot(
                            label: _template.fields[i].label,
                            latex: _fieldControllers[i].text.trim(),
                            onTap: () async {
                              final result = await _showMathSlotDialog(
                                context,
                                initialLatex: _fieldControllers[i].text.trim(),
                              );
                              if (result == null) {
                                return;
                              }
                              _fieldControllers[i].text = result;
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
              const SizedBox(height: 16),
              Text(
                'Full Formula Preview',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              MathPreview(
                latex: _latex,
                displayMode: MathDisplayMode.inline,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_LatexExprNode(_latex)),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _selectTemplate(MathTemplate template) {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    _template = template;
    _fieldControllers = _buildFieldControllers(template.defaults);
  }

  List<TextEditingController> _buildFieldControllers(List<String> values) {
    return values.map((value) => TextEditingController(text: value)).toList();
  }
}

class _ExpressionCanvas extends StatelessWidget {
  const _ExpressionCanvas({
    required this.nodes,
    required this.selectedIndex,
    required this.caretIndex,
    required this.onSelectNode,
    required this.onMoveCaret,
    required this.onEditFraction,
    required this.onEditText,
    required this.onEditLatex,
  });

  final List<_ExprNode> nodes;
  final int? selectedIndex;
  final int caretIndex;
  final ValueChanged<int> onSelectNode;
  final ValueChanged<int> onMoveCaret;
  final ValueChanged<int> onEditFraction;
  final ValueChanged<int> onEditText;
  final ValueChanged<int> onEditLatex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: nodes.isEmpty
          ? Center(
              child: GestureDetector(
                onTap: () => onMoveCaret(0),
                child: _ExpressionCaret(active: caretIndex == 0),
              ),
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _ExpressionCaretTarget(
                  active: caretIndex == 0,
                  onTap: () => onMoveCaret(0),
                ),
                for (var i = 0; i < nodes.length; i++) ...[
                  if (!(nodes[i] is _TextExprNode &&
                      (nodes[i] as _TextExprNode).text.trim().isEmpty))
                    _ExpressionNodeChip(
                      node: nodes[i],
                      selected: selectedIndex == i,
                      onTap: () => onSelectNode(i),
                      onDoubleTap: () {
                        if (nodes[i] is _FractionExprNode) {
                          onEditFraction(i);
                        } else if (nodes[i] is _LatexExprNode) {
                          onEditLatex(i);
                        } else {
                          onEditText(i);
                        }
                      },
                    ),
                  _ExpressionCaretTarget(
                    active: caretIndex == i + 1,
                    onTap: () => onMoveCaret(i + 1),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ExpressionCaretTarget extends StatelessWidget {
  const _ExpressionCaretTarget({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _ExpressionCaret(active: active),
      ),
    );
  }
}

class _ExpressionCaret extends StatelessWidget {
  const _ExpressionCaret({
    required this.active,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: active ? 4 : 12,
      height: 28,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ExpressionNodeChip extends StatelessWidget {
  const _ExpressionNodeChip({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final _ExprNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: node is _FractionExprNode
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: CompactMathInline(
                      latex: _exprNodesToLatex(
                        (node as _FractionExprNode).numerator,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 2, width: 64, color: Colors.black87),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: CompactMathInline(
                      latex: _exprNodesToLatex(
                        (node as _FractionExprNode).denominator,
                      ),
                    ),
                  ),
                ],
              )
            : node is _LatexExprNode
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: CompactMathInline(
                        latex: (node as _LatexExprNode).latex),
                  )
                : _ExpressionTextToken(text: (node as _TextExprNode).text),
      ),
    );
  }
}

class _ExpressionTextToken extends StatelessWidget {
  const _ExpressionTextToken({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox(width: 8);
    }
    if (_looksLikeMathToken(text)) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: CompactMathInline(latex: text),
      );
    }
    return Text(text);
  }
}

bool _looksLikeMathToken(String text) {
  return text.startsWith(r'\') ||
      RegExp(r'^[A-Za-z0-9+\-*/=()\[\]]+$').hasMatch(text);
}

class _TemplateInsertButton extends StatelessWidget {
  const _TemplateInsertButton({
    required this.template,
    required this.onPressed,
    this.selected = false,
  });

  final MathTemplate template;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 72, minHeight: 28),
        child: Center(
          child: CompactMathInline(
            latex: template.buildLatex(template.defaults),
          ),
        ),
      ),
    );
  }
}
