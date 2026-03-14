import 'package:flutter/material.dart';
import 'package:rich_text_editor/rich_text_editor.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DemoScreen(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late final RichTextEditorController _controller;
  String _json = '';
  String _html = '';

  @override
  void initState() {
    super.initState();
    _controller = RichTextEditorController(document: _buildDemoDocument());
    _refreshOutputs();
    _controller.addListener(_refreshOutputs);
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshOutputs);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rich Text Editor Feature Demo')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return RichTextEditor(controller: _controller);
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    const _DemoInstructions(),
                    Expanded(
                      child: RichTextEditor(controller: _controller),
                    ),
                  ],
                ),
              ),
              Container(
                width: 420,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'JSON'),
                          Tab(text: 'HTML'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OutputPanel(content: _json),
                            _OutputPanel(content: _html),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _refreshOutputs() {
    if (!mounted) {
      return;
    }
    setState(() {
      _json = _controller.toJsonString();
      _html = _controller.toHtmlString();
    });
  }

  EditorDocument _buildDemoDocument() {
    return EditorDocument(
      nodes: const [
        TextBlockNode(
          id: 'demo_heading',
          style: TextBlockStyle.heading1,
          segments: [
            TextSegment(text: 'Rich Text Editor Playground'),
          ],
        ),
        TextBlockNode(
          id: 'demo_text',
          style: TextBlockStyle.paragraph,
          segments: [
            TextSegment(text: 'Try selecting '),
            TextSegment(text: 'bold', bold: true),
            TextSegment(text: ', '),
            TextSegment(text: 'italic', italic: true),
            TextSegment(text: ', and '),
            TextSegment(text: 'underlined', underline: true),
            TextSegment(text: ' text. There is also an '),
            TextSegment(
              text: 'inline link',
              link: 'https://example.com',
            ),
            TextSegment(text: ' and inline math '),
            TextSegment(inlineMathLatex: r'\frac{a+b}{c}'),
            TextSegment(text: ' inside this sentence.'),
          ],
        ),
        TextBlockNode(
          id: 'demo_text_2',
          style: TextBlockStyle.paragraph,
          segments: [
            TextSegment(text: 'Place the caret next to this formula '),
            TextSegment(inlineMathLatex: r'\int_0^1 x^2\,dx'),
            TextSegment(
              text:
                  ' and test left/right arrow, shift+arrow, backspace, and delete.',
            ),
          ],
        ),
        ListNode(
          id: 'demo_list',
          items: [
            [
              TextSegment(
                text: 'Convert paragraphs into lists with the toolbar',
              ),
            ],
            [
              TextSegment(text: 'Tap '),
              TextSegment(inlineMathLatex: r'\alpha+\beta'),
              TextSegment(text: ' to test inline math inside lists'),
            ],
            [TextSegment(text: 'Watch JSON and HTML update on the right')],
          ],
          style: ListStyle.unordered,
        ),
        MathNode(
          id: 'demo_block_math',
          latex: r'E = mc^2',
          displayMode: MathDisplayMode.block,
        ),
        ImageNode(
          id: 'demo_image',
          url:
              'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=80',
          altText: 'Demo image block',
        ),
      ],
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}

class _DemoInstructions extends StatelessWidget {
  const _DemoInstructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: const [
          _HintChip('Select text and click Bold / Italic / Underline / Link'),
          _HintChip('Use Inline math to insert formulas into a text block'),
          _HintChip('Tap a formula to edit it'),
          _HintChip('Use Left/Right and Shift+Left/Right near a formula'),
          _HintChip('Use Backspace/Delete next to a formula to remove it'),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
