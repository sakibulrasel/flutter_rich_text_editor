import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_text_editor/rich_text_editor.dart';

void main() {
  test('controller serializes text and math nodes', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Euler identity');
    controller.insertMath(
      latex: r'e^{i\pi} + 1 = 0',
      displayMode: MathDisplayMode.block,
    );

    final json = controller.toJsonString();
    final html = controller.toHtmlString();

    expect(json, contains('Euler identity'));
    expect(json, contains(r'e^{i\\pi} + 1 = 0'));
    expect(html, contains('<p>Euler identity</p>'));
    expect(html, contains('data-node="math-block"'));
  });

  test('controller serializes list and image nodes', () {
    final controller = RichTextEditorController();

    controller.insertList(
      items: const ['First item', 'Second item'],
      ordered: true,
    );
    controller.insertImage(
      url: 'https://example.com/equation.png',
      altText: 'Equation preview',
    );

    final json = controller.toJsonString();
    final html = controller.toHtmlString();

    expect(json, contains('"type": "list"'));
    expect(json, contains('"type": "image"'));
    expect(html, contains('<ol>'));
    expect(html, contains('<li>First item</li>'));
    expect(
      html,
      contains(
        '<img src="https://example.com/equation.png" alt="Equation preview" />',
      ),
    );
  });

  test('controller serializes wrapped image nodes', () {
    final controller = RichTextEditorController();

    controller.insertImage(
      url: 'https://example.com/diagram.png',
      altText: 'Diagram',
      width: 320,
      wrapText: 'Text beside image',
      wrapAlignment: ImageWrapAlignment.left,
    );

    final json = controller.toJsonString();
    final html = controller.toHtmlString();

    expect(json, contains('"wrapText": "Text beside image"'));
    expect(json, contains('"wrapAlignment": "left"'));
    expect(html, contains('data-node="image-wrap"'));
    expect(html, contains('data-wrap-align="left"'));
    expect(html, contains('<p>Text beside image</p>'));
  });

  test('controller serializes floating image fields', () {
    final controller = RichTextEditorController();

    controller.insertImage(
      url: 'https://example.com/floating.png',
      altText: 'Floating diagram',
      width: 260,
      height: 180,
      layoutMode: ImageLayoutMode.floating,
      textWrapMode: ImageTextWrap.around,
      x: 48,
      y: 96,
      zIndex: 2,
      anchorBlockId: 'node_0',
    );

    final json = controller.toJsonString();

    expect(json, contains('"layoutMode": "floating"'));
    expect(json, contains('"textWrapMode": "around"'));
    expect(json, contains('"x": 48.0'));
    expect(json, contains('"y": 96.0'));
    expect(json, contains('"zIndex": 2'));
    expect(json, contains('"anchorBlockId": "node_0"'));
  });

  test('controller serializes floating image text anchor fields', () {
    final controller = RichTextEditorController();

    controller.insertImage(
      url: 'https://example.com/floating.png',
      altText: 'Floating diagram',
      layoutMode: ImageLayoutMode.floating,
      textWrapMode: ImageTextWrap.around,
      anchorBlockId: 'node_0',
      anchorTextOffset: 7,
      anchorListItemIndex: 1,
    );

    final json = controller.toJsonString();

    expect(json, contains('"anchorTextOffset": 7'));
    expect(json, contains('"anchorListItemIndex": 1'));
  });

  test('list items can serialize inline math', () {
    final node = ListNode(
      id: 'list_1',
      items: const [
        [
          TextSegment(text: 'Area = '),
          TextSegment(inlineMathLatex: r'\pi r^2'),
        ],
      ],
      style: ListStyle.unordered,
    );
    final controller = RichTextEditorController(
      document: EditorDocument(nodes: [node]),
    );

    expect(controller.toHtmlString(), contains('data-node="math-inline"'));
    expect(
        controller.toJsonString(), contains(r'"inlineMathLatex": "\\pi r^2"'));
  });

  test('controller serializes formatted text segments', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Hello world');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    controller.applyBoldToSelection();
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );
    controller.applyItalicToSelection();
    controller.applyLinkToSelection('https://example.com');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    controller.applyUnderlineToSelection();

    final json = controller.toJsonString();
    final html = controller.toHtmlString();

    expect(json, contains('"bold": true'));
    expect(json, contains('"italic": true'));
    expect(json, contains('"underline": true'));
    expect(json, contains('https://example.com'));
    expect(html, contains('<u><strong>Hello</strong></u>'));
    expect(
      html,
      contains('<a href="https://example.com"><em>world</em></a>'),
    );
  });

  test('inserted text inherits style from the insertion segment', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Hello world');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    controller.applyBoldToSelection();

    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Heyllo world',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    final html = controller.toHtmlString();
    expect(html, contains('<strong>Heyllo</strong> world'));
  });

  test('collapsed bold toggle applies to subsequently typed text', () {
    final controller = RichTextEditorController();

    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 0),
    );
    controller.applyBoldToSelection();

    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Bold',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    expect(controller.toHtmlString(), '<p><strong>Bold</strong></p>');
    expect(controller.isBoldActive, isTrue);
  });

  test('collapsed bold toggle can be turned off for subsequent typing', () {
    final controller = RichTextEditorController();

    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 0),
    );
    controller.applyBoldToSelection();
    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Bold',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    controller.applyBoldToSelection();
    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Bold plain',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );

    expect(controller.toHtmlString(), '<p><strong>Bold</strong> plain</p>');
    expect(controller.isBoldActive, isFalse);
  });

  test('formatted segments survive deletion', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Hello world');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection(baseOffset: 6, extentOffset: 11),
    );
    controller.applyItalicToSelection();

    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    final json = controller.toJsonString();
    final html = controller.toHtmlString();
    expect(json, isNot(contains('world')));
    expect(html, equals('<p>Hello</p>'));
  });

  test('inline math can be inserted into active text block', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Area = ');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 7),
    );
    controller.insertInlineMathToActiveText(r'\pi r^2');

    final json = controller.toJsonString();
    final html = controller.toHtmlString();

    expect(json, contains(r'"inlineMathLatex": "\\pi r^2"'));
    expect(html, contains('<p>Area = <span data-node="math-inline"'));
    expect(html, contains(r'\(\pi r^2\)'));
  });

  test('controller can export standalone html document with mathjax', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Area = ');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 7),
    );
    controller.insertInlineMathToActiveText(r'\pi r^2');

    final htmlDocument = controller.toHtmlDocumentString(title: 'Preview');

    expect(htmlDocument, contains('<!DOCTYPE html>'));
    expect(htmlDocument, contains('MathJax'));
    expect(htmlDocument, contains(r'\(\pi r^2\)'));
    expect(htmlDocument, contains('<title>Preview</title>'));
  });

  test('controller can export embeddable html snippet', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Hello');

    final snippet = controller.toEmbeddableHtmlString(
      attributes: const {'data-id': 'post-1'},
    );

    expect(snippet, contains('class="rte-viewer"'));
    expect(snippet, contains('data-rich-text-json="'));
    expect(snippet, contains('data-id="post-1"'));
    expect(snippet, contains('&quot;nodes&quot;'));
  });

  test('inline math can be inserted between existing text', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'abef');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'c+d');

    final node = controller.nodes.first as TextBlockNode;

    expect(node.plainText, 'ab${TextSegment.inlineMathPlaceholder}ef');
    expect(controller.toHtmlString(),
        contains('<p>ab<span data-node="math-inline"'));
    expect(controller.toHtmlString(), contains(r'>\(c+d\)</span>ef</p>'));
  });

  test('inline math can be inserted with an explicit saved selection', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'left right');
    controller.insertParagraph();

    controller.insertInlineMathAtSelection(
      nodeId: 'node_0',
      selection: const TextSelection.collapsed(offset: 5),
      latex: r'x^2',
    );

    final node = controller.nodes.first as TextBlockNode;

    expect(
      node.plainText,
      'left ${TextSegment.inlineMathPlaceholder}right',
    );
  });

  test('last text selection is remembered after focus changes', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'hello world');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 5),
    );
    controller.clearActiveTextSelection();

    expect(controller.activeTextNodeId, isNull);
    expect(controller.lastTextNodeId, 'node_0');
    expect(controller.lastTextSelection.baseOffset, 5);
  });

  test('block insertions use selected node as insertion anchor', () {
    final controller = RichTextEditorController();

    controller.insertParagraph(text: 'first');
    controller.insertMath(
      latex: r'E=mc^2',
      displayMode: MathDisplayMode.block,
    );
    controller.insertParagraph(text: 'last');

    final mathId = controller.nodes[1].id;
    controller.selectNode(mathId);
    controller.insertParagraph(text: 'after-math');

    expect((controller.nodes[2] as TextBlockNode).text, 'after-math');
  });

  test('inline math segment can be updated directly', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Area = ');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 7),
    );
    controller.insertInlineMathToActiveText(r'\pi r^2');

    final segmentIndex = controller.inlineMathSegmentIndexAtTextOffset(
      'node_0',
      7,
    );

    expect(segmentIndex, isNotNull);
    controller.updateInlineMathSegment('node_0', segmentIndex!, r'\frac{a}{b}');

    final html = controller.toHtmlString();
    expect(html, contains(r'data-latex="\frac{a}{b}"'));
  });

  test('deleting inline math placeholder removes the inline math segment', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'Area = ');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 7),
    );
    controller.insertInlineMathToActiveText(r'\pi r^2');

    controller.syncTextEditingValue(
      'node_0',
      const TextEditingValue(
        text: 'Area = ',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );

    final json = controller.toJsonString();
    final html = controller.toHtmlString();
    expect(json, isNot(contains(r'\\pi r^2')));
    expect(html, equals('<p>Area = </p>'));
  });

  test('backspace at inline math boundary removes the inline math segment', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.deleteInlineMathAtBoundary(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection.collapsed(offset: 3),
      ),
      backward: true,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.text, 'A=');
    expect(controller.toHtmlString(), '<p>A=</p>');
  });

  test('delete at inline math boundary removes the inline math segment', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.deleteInlineMathAtBoundary(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection.collapsed(offset: 2),
      ),
      backward: false,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.text, 'A=');
    expect(controller.toHtmlString(), '<p>A=</p>');
  });

  test('arrow right skips over inline math placeholder', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.moveCaretAcrossInlineMath(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection.collapsed(offset: 2),
      ),
      forward: true,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.selection.extentOffset, 3);
  });

  test('arrow left skips over inline math placeholder', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.moveCaretAcrossInlineMath(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection.collapsed(offset: 3),
      ),
      forward: false,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.selection.extentOffset, 2);
  });

  test('shift+arrow right expands selection across inline math', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.expandSelectionAcrossInlineMath(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection(baseOffset: 2, extentOffset: 2),
      ),
      forward: true,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.selection.baseOffset, 2);
    expect(nextValue.selection.extentOffset, 3);
  });

  test('shift+arrow left expands selection across inline math', () {
    final controller = RichTextEditorController();

    controller.updateTextNode('node_0', 'A=');
    controller.setActiveTextSelection(
      'node_0',
      const TextSelection.collapsed(offset: 2),
    );
    controller.insertInlineMathToActiveText(r'x^2');

    final nextValue = controller.expandSelectionAcrossInlineMath(
      'node_0',
      const TextEditingValue(
        text: 'A=${TextSegment.inlineMathPlaceholder}',
        selection: TextSelection(baseOffset: 3, extentOffset: 3),
      ),
      forward: false,
    );

    expect(nextValue, isNotNull);
    expect(nextValue!.selection.baseOffset, 3);
    expect(nextValue.selection.extentOffset, 2);
  });
}
