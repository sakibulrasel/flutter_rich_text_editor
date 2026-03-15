import 'package:flutter/material.dart';
import 'package:rich_text_editor/rich_text_editor.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _rendererScriptUrl =
    'https://cdn.jsdelivr.net/npm/rich-text-editor-renderer@0.4.0/dist/index.global.js?build=20260315';
const _mathJaxScriptUrl =
    'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js';

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
  String _htmlDocument = '';
  String _embeddableHtml = '';

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
      appBar: AppBar(
        title: const Text('Rich Text Editor Feature Demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                // const _DemoInstructions(),
                Expanded(
                  child: RichTextEditor(controller: _controller),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // const _DemoInstructions(),
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
      _embeddableHtml = _controller.toEmbeddableHtmlString();
      _htmlDocument = _buildPreviewDocument(_embeddableHtml);
    });
  }

  Future<void> _submit() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => HtmlPreviewScreen(
          bodyHtml: _html,
          embeddableHtml: _embeddableHtml,
          htmlDocument: _htmlDocument,
          documentJson: _json,
        ),
      ),
    );

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    _controller.replaceDocument(EditorDocument.fromJsonString(result));
  }

  String _buildPreviewDocument(String embeddableHtml) {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rich Text Editor Preview</title>
    <style>
      body {
        margin: 0;
        padding: 20px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        font-size: 16px;
        line-height: 1.6;
        color: #1f2937;
        background: #ffffff;
      }
    </style>
    <script>
      window.MathJax = {
        tex: {
          inlineMath: [['\\\\(', '\\\\)']],
          displayMath: [['\\\\[', '\\\\]']]
        }
      };
    </script>
    <script async src="$_mathJaxScriptUrl"></script>
    <script src="$_rendererScriptUrl"></script>
  </head>
  <body>
    $embeddableHtml
  </body>
</html>
''';
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

class HtmlPreviewScreen extends StatefulWidget {
  const HtmlPreviewScreen({
    super.key,
    required this.bodyHtml,
    required this.embeddableHtml,
    required this.htmlDocument,
    required this.documentJson,
  });

  final String bodyHtml;
  final String embeddableHtml;
  final String htmlDocument;
  final String documentJson;

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController _webViewController;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(widget.htmlDocument);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submitted HTML'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(widget.documentJson);
              },
              child: const Text('Edit'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WebView preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: WebViewWidget(controller: _webViewController),
                    ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),

          ],
        ),
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
          _HintChip('Use Bold / Italic / Underline with or without selection'),
          _HintChip('Use Inline math to insert formulas into a text block'),
          _HintChip('Tap a formula to edit it'),
          _HintChip('Use Left/Right and Shift+Left/Right near a formula'),
          _HintChip('Use Backspace/Delete next to a formula to remove it'),
          _HintChip(
              'Submit opens the generated HTML, Edit returns to the editor'),
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
