enum MathCategory {
  plainText,
  fractions,
  scripts,
  roots,
  calculus,
  matrices,
  symbols,
}

class MathFieldSpec {
  const MathFieldSpec({
    required this.label,
    this.hint = '',
  });

  final String label;
  final String hint;
}

typedef MathLatexBuilder = String Function(List<String> values);
typedef MathLatexParser = List<String>? Function(String latex);

class MathTemplate {
  const MathTemplate({
    required this.id,
    required this.label,
    required this.category,
    required this.fields,
    required this.defaults,
    required this.buildLatex,
    this.parseLatex,
  });

  final String id;
  final String label;
  final MathCategory category;
  final List<MathFieldSpec> fields;
  final List<String> defaults;
  final MathLatexBuilder buildLatex;
  final MathLatexParser? parseLatex;
}

class ParsedMathTemplate {
  const ParsedMathTemplate({
    required this.template,
    required this.values,
  });

  final MathTemplate template;
  final List<String> values;
}

final List<MathTemplate> kMathTemplates = <MathTemplate>[
  MathTemplate(
    id: 'plain_expression',
    label: 'Expression',
    category: MathCategory.plainText,
    fields: const [
      MathFieldSpec(label: 'Expression'),
    ],
    defaults: const ['a+b'],
    buildLatex: (values) => values[0],
  ),
  MathTemplate(
    id: 'fraction',
    label: 'Fraction',
    category: MathCategory.fractions,
    fields: const [
      MathFieldSpec(label: 'Numerator'),
      MathFieldSpec(label: 'Denominator'),
    ],
    defaults: const ['', ''],
    buildLatex: (values) => r'\frac{' '${values[0]}' '}{' '${values[1]}' '}',
    parseLatex: (latex) => _matchGroups(
      RegExp(r'^\\frac\{(.+)\}\{(.+)\}$'),
      latex,
      2,
    ),
  ),
  MathTemplate(
    id: 'power',
    label: 'Power',
    category: MathCategory.scripts,
    fields: const [
      MathFieldSpec(label: 'Base', hint: 'x'),
      MathFieldSpec(label: 'Exponent', hint: '2'),
    ],
    defaults: const ['x', '2'],
    buildLatex: (values) => '${values[0]}^{${values[1]}}',
    parseLatex: _parsePowerLike,
  ),
  MathTemplate(
    id: 'subscript',
    label: 'Subscript',
    category: MathCategory.scripts,
    fields: const [
      MathFieldSpec(label: 'Base', hint: 'H'),
      MathFieldSpec(label: 'Subscript', hint: '2'),
    ],
    defaults: const ['H', '2'],
    buildLatex: (values) => '${values[0]}_{${values[1]}}',
    parseLatex: _parseSubscriptLike,
  ),
  MathTemplate(
    id: 'square_root',
    label: 'Square Root',
    category: MathCategory.roots,
    fields: const [
      MathFieldSpec(label: 'Expression', hint: 'x+1'),
    ],
    defaults: const ['x+1'],
    buildLatex: (values) => r'\sqrt{' '${values[0]}' '}',
    parseLatex: (latex) => _matchGroups(
      RegExp(r'^\\sqrt\{(.+)\}$'),
      latex,
      1,
    ),
  ),
  MathTemplate(
    id: 'nth_root',
    label: 'Nth Root',
    category: MathCategory.roots,
    fields: const [
      MathFieldSpec(label: 'Index', hint: '3'),
      MathFieldSpec(label: 'Expression', hint: 'x'),
    ],
    defaults: const ['3', 'x'],
    buildLatex: (values) => r'\sqrt[' '${values[0]}' ']{' '${values[1]}' '}',
    parseLatex: (latex) => _matchGroups(
      RegExp(r'^\\sqrt\[(.+)\]\{(.+)\}$'),
      latex,
      2,
    ),
  ),
  MathTemplate(
    id: 'summation',
    label: 'Summation',
    category: MathCategory.calculus,
    fields: const [
      MathFieldSpec(label: 'Lower', hint: 'i=1'),
      MathFieldSpec(label: 'Upper', hint: 'n'),
      MathFieldSpec(label: 'Expression', hint: 'x_i'),
    ],
    defaults: const ['i=1', 'n', 'x_i'],
    buildLatex: (values) => r'\sum_{'
        '${values[0]}'
        '}^{'
        '${values[1]}'
        '} '
        '${values[2]}',
    parseLatex: _parseSummationLike,
  ),
  MathTemplate(
    id: 'integral',
    label: 'Integral',
    category: MathCategory.calculus,
    fields: const [
      MathFieldSpec(label: 'Lower', hint: '0'),
      MathFieldSpec(label: 'Upper', hint: '1'),
      MathFieldSpec(label: 'Expression', hint: 'x^2'),
      MathFieldSpec(label: 'Variable', hint: 'x'),
    ],
    defaults: const ['0', '1', 'x^2', 'x'],
    buildLatex: (values) => r'\int_{'
        '${values[0]}'
        '}^{'
        '${values[1]}'
        '} '
        '${values[2]}'
        r' \, d'
        '${values[3]}',
    parseLatex: _parseIntegralLike,
  ),
  MathTemplate(
    id: 'matrix_2x2',
    label: 'Matrix 2x2',
    category: MathCategory.matrices,
    fields: const [
      MathFieldSpec(label: 'a11', hint: 'a'),
      MathFieldSpec(label: 'a12', hint: 'b'),
      MathFieldSpec(label: 'a21', hint: 'c'),
      MathFieldSpec(label: 'a22', hint: 'd'),
    ],
    defaults: const ['a', 'b', 'c', 'd'],
    buildLatex: (values) => r'\begin{bmatrix} '
        '${values[0]}'
        ' & '
        '${values[1]}'
        r' \\ '
        '${values[2]}'
        ' & '
        '${values[3]}'
        r' \end{bmatrix}',
    parseLatex: (latex) => _matchGroups(
      RegExp(
        r'^\\begin\{bmatrix\}\s*(.+)\s*&\s*(.+)\s*\\\\\s*(.+)\s*&\s*(.+)\s*\\end\{bmatrix\}$',
      ),
      latex,
      4,
    ),
  ),
  MathTemplate(
    id: 'symbol_alpha',
    label: 'alpha',
    category: MathCategory.symbols,
    fields: const [],
    defaults: const [],
    buildLatex: (_) => r'\alpha',
    parseLatex: (latex) => latex == r'\alpha' ? const [] : null,
  ),
  MathTemplate(
    id: 'symbol_pi',
    label: 'pi',
    category: MathCategory.symbols,
    fields: const [],
    defaults: const [],
    buildLatex: (_) => r'\pi',
    parseLatex: (latex) => latex == r'\pi' ? const [] : null,
  ),
  MathTemplate(
    id: 'symbol_theta',
    label: 'theta',
    category: MathCategory.symbols,
    fields: const [],
    defaults: const [],
    buildLatex: (_) => r'\theta',
    parseLatex: (latex) => latex == r'\theta' ? const [] : null,
  ),
];

const Map<MathCategory, String> kMathCategoryLabels = <MathCategory, String>{
  MathCategory.plainText: 'Expression',
  MathCategory.fractions: 'Fractions',
  MathCategory.scripts: 'Scripts',
  MathCategory.roots: 'Roots',
  MathCategory.calculus: 'Calculus',
  MathCategory.matrices: 'Matrices',
  MathCategory.symbols: 'Symbols',
};

const List<String> kMathSymbolPalette = <String>[
  '+',
  '-',
  r'\pm',
  r'\times',
  r'\div',
  '=',
  r'\neq',
  r'\leq',
  r'\geq',
  r'\alpha',
  r'\beta',
  r'\theta',
  r'\pi',
  r'\sqrt{}',
];

ParsedMathTemplate? parseMathTemplate(String latex) {
  for (final template in kMathTemplates) {
    final values = template.parseLatex?.call(latex);
    if (values != null) {
      return ParsedMathTemplate(template: template, values: values);
    }
  }
  return null;
}

List<String>? _matchGroups(RegExp expression, String value, int count) {
  final match = expression.firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  return List<String>.generate(count, (index) => match.group(index + 1) ?? '');
}

List<String>? _parsePowerLike(String latex) {
  return _matchGroups(RegExp(r'^(.+)\^\{(.+)\}$'), latex, 2) ??
      _matchGroups(RegExp(r'^(.+)\^([A-Za-z0-9])$'), latex, 2);
}

List<String>? _parseSubscriptLike(String latex) {
  return _matchGroups(RegExp(r'^(.+)_\{(.+)\}$'), latex, 2) ??
      _matchGroups(RegExp(r'^(.+)_([A-Za-z0-9])$'), latex, 2);
}

List<String>? _parseSummationLike(String latex) {
  return _matchGroups(RegExp(r'^\\sum_\{(.+)\}\^\{(.+)\}\s+(.+)$'), latex, 3) ??
      _matchGroups(RegExp(r'^\\sum_([^\\s^]+)\^([^\\s]+)\s+(.+)$'), latex, 3);
}

List<String>? _parseIntegralLike(String latex) {
  return _matchGroups(
        RegExp(r'^\\int_\{(.+)\}\^\{(.+)\}\s+(.+?)\s*\\,\s*d(.+)$'),
        latex,
        4,
      ) ??
      _matchGroups(
        RegExp(r'^\\int_([^\\s^]+)\^([^\\s]+)\s+(.+?)\s*\\,\s*d(.+)$'),
        latex,
        4,
      ) ??
      _matchGroups(
        RegExp(r'^\\int_([^\\s^]+)\^([^\\s]+)\s+(.+?)\s*d([A-Za-z])$'),
        latex,
        4,
      );
}
