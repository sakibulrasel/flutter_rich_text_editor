import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class CompactMathInline extends StatelessWidget {
  const CompactMathInline({
    super.key,
    required this.latex,
  });

  final String latex;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Math.tex(
        latex.trim().isEmpty ? r'\placeholder{}' : latex,
        mathStyle: MathStyle.text,
        onErrorFallback: (error) {
          return Text(
            latex,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        },
      ),
    );
  }
}

class MathTemplateFieldSlot extends StatelessWidget {
  const MathTemplateFieldSlot({
    super.key,
    required this.label,
    required this.latex,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final String latex;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasValue = latex.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            if (hasValue)
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CompactMathInline(latex: latex),
                ),
              )
            else
              Text(
                'Tap to compose',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class MathFractionVisualComposer extends StatelessWidget {
  const MathFractionVisualComposer({
    super.key,
    required this.numeratorLatex,
    required this.denominatorLatex,
    required this.onEditNumerator,
    required this.onEditDenominator,
  });

  final String numeratorLatex;
  final String denominatorLatex;
  final VoidCallback onEditNumerator;
  final VoidCallback onEditDenominator;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MathFractionSlot(
              label: 'Numerator',
              latex: numeratorLatex,
              onTap: onEditNumerator,
            ),
            const SizedBox(height: 10),
            Divider(
              thickness: 2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 10),
            _MathFractionSlot(
              label: 'Denominator',
              latex: denominatorLatex,
              onTap: onEditDenominator,
            ),
          ],
        ),
      ),
    );
  }
}

class MathRootVisualComposer extends StatelessWidget {
  const MathRootVisualComposer({
    super.key,
    required this.radicandLatex,
    required this.onEditRadicand,
  });

  final String radicandLatex;
  final VoidCallback onEditRadicand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
          final containerWidth = maxWidth.clamp(180.0, 360.0);
          final slotWidth = (containerWidth - 64).clamp(120.0, 250.0);
          final useColumn = containerWidth < 280;
          return Container(
            width: containerWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: useColumn
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('√',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: slotWidth,
                        child: _MathFormulaSlot(
                          label: 'Radicand',
                          latex: radicandLatex,
                          onTap: onEditRadicand,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: Text(
                          '√',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      SizedBox(
                        width: slotWidth,
                        child: _MathFormulaSlot(
                          label: 'Radicand',
                          latex: radicandLatex,
                          onTap: onEditRadicand,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class MathPowerVisualComposer extends StatelessWidget {
  const MathPowerVisualComposer({
    super.key,
    required this.baseLatex,
    required this.exponentLatex,
    required this.onEditBase,
    required this.onEditExponent,
  });

  final String baseLatex;
  final String exponentLatex;
  final VoidCallback onEditBase;
  final VoidCallback onEditExponent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MathFormulaSlot(
                label: 'Base',
                latex: baseLatex,
                onTap: onEditBase,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Transform.translate(
                offset: const Offset(0, -10),
                child: _MathFormulaSlot(
                  label: 'Exponent',
                  latex: exponentLatex,
                  onTap: onEditExponent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MathSubscriptVisualComposer extends StatelessWidget {
  const MathSubscriptVisualComposer({
    super.key,
    required this.baseLatex,
    required this.subscriptLatex,
    required this.onEditBase,
    required this.onEditSubscript,
  });

  final String baseLatex;
  final String subscriptLatex;
  final VoidCallback onEditBase;
  final VoidCallback onEditSubscript;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _MathFormulaSlot(
                label: 'Base',
                latex: baseLatex,
                onTap: onEditBase,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Transform.translate(
                offset: const Offset(0, 10),
                child: _MathFormulaSlot(
                  label: 'Subscript',
                  latex: subscriptLatex,
                  onTap: onEditSubscript,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MathNthRootVisualComposer extends StatelessWidget {
  const MathNthRootVisualComposer({
    super.key,
    required this.indexLatex,
    required this.radicandLatex,
    required this.onEditIndex,
    required this.onEditRadicand,
  });

  final String indexLatex;
  final String radicandLatex;
  final VoidCallback onEditIndex;
  final VoidCallback onEditRadicand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 420.0;
          final containerWidth = maxWidth.clamp(220.0, 420.0);
          final useColumn = containerWidth < 340;
          final indexWidth = useColumn ? containerWidth - 32 : 72.0;
          final radicandWidth = useColumn
              ? containerWidth - 32
              : (containerWidth - 128).clamp(120.0, 230.0);
          return Container(
            width: containerWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: useColumn
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: indexWidth,
                        child: _MathFormulaSlot(
                          label: 'Index',
                          latex: indexLatex,
                          onTap: onEditIndex,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('√',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: radicandWidth,
                        child: _MathFormulaSlot(
                          label: 'Radicand',
                          latex: radicandLatex,
                          onTap: onEditRadicand,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: indexWidth,
                        child: _MathFormulaSlot(
                          label: 'Index',
                          latex: indexLatex,
                          onTap: onEditIndex,
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, right: 8, bottom: 4),
                        child: Text(
                          '√',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      SizedBox(
                        width: radicandWidth,
                        child: _MathFormulaSlot(
                          label: 'Radicand',
                          latex: radicandLatex,
                          onTap: onEditRadicand,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class MathIntegralVisualComposer extends StatelessWidget {
  const MathIntegralVisualComposer({
    super.key,
    required this.lowerLatex,
    required this.upperLatex,
    required this.expressionLatex,
    required this.variableLatex,
    required this.onEditLower,
    required this.onEditUpper,
    required this.onEditExpression,
    required this.onEditVariable,
  });

  final String lowerLatex;
  final String upperLatex;
  final String expressionLatex;
  final String variableLatex;
  final VoidCallback onEditLower;
  final VoidCallback onEditUpper;
  final VoidCallback onEditExpression;
  final VoidCallback onEditVariable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 640.0;
          final containerWidth = maxWidth.clamp(280.0, 640.0);
          final useColumn = containerWidth < 520;
          return Container(
            width: containerWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: useColumn
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('∫',
                              style: Theme.of(context).textTheme.displayMedium),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                _MathFormulaSlot(
                                  label: 'Upper',
                                  latex: upperLatex,
                                  onTap: onEditUpper,
                                ),
                                const SizedBox(height: 8),
                                _MathFormulaSlot(
                                  label: 'Lower',
                                  latex: lowerLatex,
                                  onTap: onEditLower,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MathFormulaSlot(
                        label: 'Expression',
                        latex: expressionLatex,
                        onTap: onEditExpression,
                      ),
                      const SizedBox(height: 12),
                      _MathFormulaSlot(
                        label: 'Variable',
                        latex: variableLatex,
                        onTap: onEditVariable,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MathFormulaSlot(
                              label: 'Upper',
                              latex: upperLatex,
                              onTap: onEditUpper,
                            ),
                            const SizedBox(height: 8),
                            _MathFormulaSlot(
                              label: 'Lower',
                              latex: lowerLatex,
                              onTap: onEditLower,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '∫',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                      ),
                      Expanded(
                        child: _MathFormulaSlot(
                          label: 'Expression',
                          latex: expressionLatex,
                          onTap: onEditExpression,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 92,
                        child: _MathFormulaSlot(
                          label: 'Variable',
                          latex: variableLatex,
                          onTap: onEditVariable,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class MathSummationVisualComposer extends StatelessWidget {
  const MathSummationVisualComposer({
    super.key,
    required this.lowerLatex,
    required this.upperLatex,
    required this.expressionLatex,
    required this.onEditLower,
    required this.onEditUpper,
    required this.onEditExpression,
  });

  final String lowerLatex;
  final String upperLatex;
  final String expressionLatex;
  final VoidCallback onEditLower;
  final VoidCallback onEditUpper;
  final VoidCallback onEditExpression;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 620.0;
          final containerWidth = maxWidth.clamp(280.0, 620.0);
          final useColumn = containerWidth < 500;
          return Container(
            width: containerWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: useColumn
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('∑',
                              style: Theme.of(context).textTheme.displayMedium),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                _MathFormulaSlot(
                                  label: 'Upper',
                                  latex: upperLatex,
                                  onTap: onEditUpper,
                                ),
                                const SizedBox(height: 8),
                                _MathFormulaSlot(
                                  label: 'Lower',
                                  latex: lowerLatex,
                                  onTap: onEditLower,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MathFormulaSlot(
                        label: 'Expression',
                        latex: expressionLatex,
                        onTap: onEditExpression,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MathFormulaSlot(
                              label: 'Upper',
                              latex: upperLatex,
                              onTap: onEditUpper,
                            ),
                            const SizedBox(height: 8),
                            _MathFormulaSlot(
                              label: 'Lower',
                              latex: lowerLatex,
                              onTap: onEditLower,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '∑',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                      ),
                      Expanded(
                        child: _MathFormulaSlot(
                          label: 'Expression',
                          latex: expressionLatex,
                          onTap: onEditExpression,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class MathMatrixVisualComposer extends StatelessWidget {
  const MathMatrixVisualComposer({
    super.key,
    required this.values,
    required this.onEditCell,
  }) : assert(values.length == 4);

  final List<String> values;
  final ValueChanged<int> onEditCell;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('[', style: Theme.of(context).textTheme.displayLarge),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.8,
                ),
                itemBuilder: (context, index) {
                  return _MathFormulaSlot(
                    label: 'a${index ~/ 2 + 1}${index % 2 + 1}',
                    latex: values[index],
                    onTap: () => onEditCell(index),
                  );
                },
              ),
            ),
            Text(']', style: Theme.of(context).textTheme.displayLarge),
          ],
        ),
      ),
    );
  }
}

class _MathFractionSlot extends StatelessWidget {
  const _MathFractionSlot({
    required this.label,
    required this.latex,
    required this.onTap,
  });

  final String label;
  final String latex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = latex.trim().isNotEmpty;
    final placeholderLatex = switch (label) {
      'Numerator' => 'a',
      'Denominator' => 'b',
      _ => '',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 72, maxHeight: 132),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            if (hasValue)
              Flexible(
                child: SingleChildScrollView(
                  child: CompactMathInline(latex: latex),
                ),
              )
            else
              Opacity(
                opacity: 0.65,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (placeholderLatex.isNotEmpty)
                      CompactMathInline(latex: placeholderLatex),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to edit',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MathFormulaSlot extends StatelessWidget {
  const _MathFormulaSlot({
    required this.label,
    required this.latex,
    required this.onTap,
  });

  final String label;
  final String latex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = latex.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 72, maxHeight: 132),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            if (hasValue)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CompactMathInline(latex: latex),
                ),
              )
            else
              Text(
                'Tap to edit',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
