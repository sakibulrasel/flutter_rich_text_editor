import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rich_text_editor/src/document/editor_document.dart';
import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';
import 'package:rich_text_editor/src/document/nodes/image_node.dart';
import 'package:rich_text_editor/src/document/nodes/list_node.dart';
import 'package:rich_text_editor/src/document/nodes/math_node.dart';
import 'package:rich_text_editor/src/document/nodes/text_block_node.dart';

class RichTextEditorController extends ChangeNotifier {
  RichTextEditorController({EditorDocument? document})
      : _document = document ?? EditorDocument.empty();

  EditorDocument _document;
  final List<EditorDocument> _undoStack = <EditorDocument>[];
  final List<EditorDocument> _redoStack = <EditorDocument>[];
  String? _activeTextNodeId;
  String? _selectedNodeId;
  String? _activeListNodeId;
  int? _activeListItemIndex;
  TextSelection _activeListSelection =
      const TextSelection.collapsed(offset: -1);
  TextSelection _activeSelection = const TextSelection.collapsed(offset: -1);
  String? _lastTextNodeId;
  TextSelection _lastTextSelection = const TextSelection.collapsed(offset: -1);
  String? _lastListNodeId;
  int? _lastListItemIndex;
  TextSelection _lastListSelection = const TextSelection.collapsed(offset: -1);
  TextSegment _activeTypingStyle = const TextSegment(text: '');
  int _focusRequestVersion = 0;

  EditorDocument get document => _document;

  List<EditorNode> get nodes => _document.nodes;

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  String? get activeTextNodeId => _activeTextNodeId;

  String? get selectedNodeId => _selectedNodeId;

  TextSelection get activeSelection => _activeSelection;
  String? get activeListNodeId => _activeListNodeId;
  int? get activeListItemIndex => _activeListItemIndex;
  TextSelection get activeListSelection => _activeListSelection;

  String? get lastTextNodeId => _lastTextNodeId;

  TextSelection get lastTextSelection => _lastTextSelection;
  String? get lastListNodeId => _lastListNodeId;
  int? get lastListItemIndex => _lastListItemIndex;
  TextSelection get lastListSelection => _lastListSelection;
  bool get isBoldActive => _isInlineFormatActive((segment) => segment.bold);
  bool get isItalicActive => _isInlineFormatActive((segment) => segment.italic);
  bool get isUnderlineActive =>
      _isInlineFormatActive((segment) => segment.underline);

  int get focusRequestVersion => _focusRequestVersion;

  void replaceDocument(EditorDocument document) {
    _pushUndoState();
    _document = document;
    _redoStack.clear();
    notifyListeners();
  }

  void updateTextNode(String id, String text) {
    _replaceNode(
      id,
      (node) => (node as TextBlockNode).copyWith(text: text),
      shouldPushHistory: false,
    );
  }

  void syncTextEditingValue(String id, TextEditingValue value) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! TextBlockNode) {
      return;
    }
    if (node.plainText == value.text) {
      _activeTextNodeId = id;
      _activeSelection = value.selection;
      _activeListNodeId = null;
      _activeListItemIndex = null;
      _activeListSelection = const TextSelection.collapsed(offset: -1);
      if (value.selection.isValid) {
        _rememberTextSelection(id, value.selection);
      }
      _syncTypingStyleForActiveTarget();
      notifyListeners();
      return;
    }

    _pushUndoState();
    final nextNodes = nodes.toList();
    nextNodes[index] = node.copyWith(
      segments: _rebuildSegmentsForTextEdit(node.segments, value.text),
    );
    _document = _document.copyWith(nodes: nextNodes);
    _activeTextNodeId = id;
    _activeSelection = value.selection;
    _activeListNodeId = null;
    _activeListItemIndex = null;
    _activeListSelection = const TextSelection.collapsed(offset: -1);
    if (value.selection.isValid) {
      _rememberTextSelection(id, value.selection);
    }
    _syncTypingStyleForActiveTarget();
    _redoStack.clear();
    notifyListeners();
  }

  TextEditingValue? deleteInlineMathAtBoundary(
    String id,
    TextEditingValue value, {
    required bool backward,
  }) {
    if (!value.selection.isValid || !value.selection.isCollapsed) {
      return null;
    }

    final offset = value.selection.extentOffset;
    final targetOffset = backward ? offset - 1 : offset;
    if (targetOffset < 0 || targetOffset >= value.text.length) {
      return null;
    }
    if (value.text[targetOffset] != TextSegment.inlineMathPlaceholder) {
      return null;
    }

    final nextText =
        value.text.replaceRange(targetOffset, targetOffset + 1, '');
    final nextSelection = TextSelection.collapsed(offset: targetOffset);
    final nextValue = value.copyWith(
      text: nextText,
      selection: nextSelection,
      composing: TextRange.empty,
    );
    syncTextEditingValue(id, nextValue);
    return nextValue;
  }

  TextEditingValue? moveCaretAcrossInlineMath(
    String id,
    TextEditingValue value, {
    required bool forward,
  }) {
    if (!value.selection.isValid || !value.selection.isCollapsed) {
      return null;
    }

    final offset = value.selection.extentOffset;
    final targetOffset = forward ? offset : offset - 1;
    if (targetOffset < 0 || targetOffset >= value.text.length) {
      return null;
    }
    if (value.text[targetOffset] != TextSegment.inlineMathPlaceholder) {
      return null;
    }

    final nextOffset = forward ? targetOffset + 1 : targetOffset;
    final nextValue = value.copyWith(
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _activeTextNodeId = id;
    _activeSelection = nextValue.selection;
    _rememberTextSelection(id, nextValue.selection);
    _syncTypingStyleForActiveTarget();
    notifyListeners();
    return nextValue;
  }

  TextEditingValue? expandSelectionAcrossInlineMath(
    String id,
    TextEditingValue value, {
    required bool forward,
  }) {
    if (!value.selection.isValid) {
      return null;
    }

    final extent = value.selection.extentOffset;
    final targetOffset = forward ? extent : extent - 1;
    if (targetOffset < 0 || targetOffset >= value.text.length) {
      return null;
    }
    if (value.text[targetOffset] != TextSegment.inlineMathPlaceholder) {
      return null;
    }

    final nextExtent = forward ? targetOffset + 1 : targetOffset;
    final nextSelection = TextSelection(
      baseOffset: value.selection.baseOffset,
      extentOffset: nextExtent,
    );
    final nextValue = value.copyWith(selection: nextSelection);
    _activeTextNodeId = id;
    _activeSelection = nextSelection;
    _rememberTextSelection(id, nextSelection);
    _syncTypingStyleForActiveTarget();
    notifyListeners();
    return nextValue;
  }

  void updateTextStyle(String id, TextBlockStyle style) {
    _replaceNode(id, (node) => (node as TextBlockNode).copyWith(style: style));
  }

  void setActiveTextSelection(String id, TextSelection selection) {
    if (_activeTextNodeId == id &&
        _selectedNodeId == id &&
        _activeSelection == selection &&
        _activeListNodeId == null &&
        _activeListItemIndex == null &&
        _activeListSelection == const TextSelection.collapsed(offset: -1)) {
      return;
    }
    _activeTextNodeId = id;
    _selectedNodeId = id;
    _activeListNodeId = null;
    _activeListItemIndex = null;
    _activeListSelection = const TextSelection.collapsed(offset: -1);
    _activeSelection = selection;
    if (selection.isValid) {
      _rememberTextSelection(id, selection);
    }
    _syncTypingStyleForActiveTarget();
    notifyListeners();
  }

  void clearActiveTextSelection() {
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    notifyListeners();
  }

  void setActiveListItemSelection(
    String nodeId,
    int itemIndex,
    TextSelection selection,
  ) {
    if (_activeListNodeId == nodeId &&
        _activeListItemIndex == itemIndex &&
        _activeListSelection == selection &&
        _selectedNodeId == nodeId &&
        _activeTextNodeId == null &&
        _activeSelection == const TextSelection.collapsed(offset: -1)) {
      return;
    }
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    _activeListNodeId = nodeId;
    _activeListItemIndex = itemIndex;
    _activeListSelection = selection;
    _selectedNodeId = nodeId;
    if (selection.isValid) {
      _lastListNodeId = nodeId;
      _lastListItemIndex = itemIndex;
      _lastListSelection = selection;
    }
    _syncTypingStyleForActiveTarget();
    notifyListeners();
  }

  void syncListItemEditingValue(
    String nodeId,
    int itemIndex,
    TextEditingValue value,
  ) {
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! ListNode || itemIndex < 0 || itemIndex >= node.items.length) {
      return;
    }
    final item = node.items[itemIndex];
    final previousText = item.map((segment) => segment.plainText).join();
    if (previousText == value.text) {
      _activeListNodeId = nodeId;
      _activeListItemIndex = itemIndex;
      _activeListSelection = value.selection;
      _selectedNodeId = nodeId;
      if (value.selection.isValid) {
        _lastListNodeId = nodeId;
        _lastListItemIndex = itemIndex;
        _lastListSelection = value.selection;
      }
      _syncTypingStyleForActiveTarget();
      notifyListeners();
      return;
    }

    _pushUndoState();
    final nextItems = node.items.toList();
    nextItems[itemIndex] = _rebuildSegmentsForTextEdit(item, value.text);
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(items: nextItems);
    _document = _document.copyWith(nodes: nextNodes);
    _activeListNodeId = nodeId;
    _activeListItemIndex = itemIndex;
    _activeListSelection = value.selection;
    _selectedNodeId = nodeId;
    if (value.selection.isValid) {
      _lastListNodeId = nodeId;
      _lastListItemIndex = itemIndex;
      _lastListSelection = value.selection;
    }
    _syncTypingStyleForActiveTarget();
    _redoStack.clear();
    notifyListeners();
  }

  void selectNode(String id) {
    if (_selectedNodeId == id) {
      return;
    }
    _selectedNodeId = id;
    notifyListeners();
  }

  void applyBoldToSelection() {
    final nextValue = !isBoldActive;
    _applyInlineFormat((segment) => segment.copyWith(bold: nextValue));
  }

  void applyItalicToSelection() {
    final nextValue = !isItalicActive;
    _applyInlineFormat((segment) => segment.copyWith(italic: nextValue));
  }

  void applyUnderlineToSelection() {
    final nextValue = !isUnderlineActive;
    _applyInlineFormat(
      (segment) => segment.copyWith(underline: nextValue),
    );
  }

  void applyLinkToSelection(String link) {
    if (link.trim().isEmpty) {
      return;
    }
    _applyInlineFormat((segment) => segment.copyWith(link: link.trim()));
  }

  void clearLinkFromSelection() {
    _applyInlineFormat((segment) => segment.copyWith(clearLink: true));
  }

  void applyHeadingToActiveText(TextBlockStyle style) {
    final nodeId = _activeTextNodeId;
    if (nodeId == null) {
      return;
    }
    updateTextStyle(nodeId, style);
  }

  void convertActiveTextBlockToList({required bool ordered}) {
    final nodeId = _activeTextNodeId;
    if (nodeId == null) {
      return;
    }
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! TextBlockNode) {
      return;
    }

    _pushUndoState();
    final nextNodes = nodes.toList();
    final lines = node.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    nextNodes[index] = ListNode(
      id: _nextId(),
      items: (lines.isEmpty ? const [''] : lines)
          .map((line) => <TextSegment>[TextSegment(text: line)])
          .toList(),
      style: ordered ? ListStyle.ordered : ListStyle.unordered,
    );
    _document = _document.copyWith(nodes: nextNodes);
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    _redoStack.clear();
    notifyListeners();
  }

  void insertInlineMathToActiveText(String latex) {
    final nodeId = _activeTextNodeId;
    if (nodeId == null || latex.trim().isEmpty) {
      return;
    }
    insertInlineMathAtSelection(
      nodeId: nodeId,
      selection: _activeSelection,
      latex: latex,
    );
  }

  void insertInlineMathAtSelection({
    required String nodeId,
    required TextSelection selection,
    required String latex,
  }) {
    if (latex.trim().isEmpty) {
      return;
    }
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! TextBlockNode) {
      return;
    }

    final normalizedSelection = _normalizedSelection(selection);
    final nextSegments = <TextSegment>[
      ..._sliceSegments(node.segments, 0, normalizedSelection.start),
      _styleForInsertedText(
        node.segments,
        preferIndex: normalizedSelection.start > 0
            ? normalizedSelection.start - 1
            : normalizedSelection.start,
      ).copyWith(text: '', inlineMathLatex: latex.trim()),
      ..._sliceSegments(
        node.segments,
        normalizedSelection.end,
        _plainTextLength(node.segments),
      ),
    ];

    _pushUndoState();
    final nextNodes = nodes.toList();
    nextNodes[index] = node.copyWith(segments: _mergeSegments(nextSegments));
    _document = _document.copyWith(nodes: nextNodes);
    final caretOffset = normalizedSelection.start + 1;
    _activeTextNodeId = nodeId;
    _selectedNodeId = nodeId;
    _activeSelection = TextSelection.collapsed(offset: caretOffset);
    _rememberTextSelection(nodeId, _activeSelection);
    _syncTypingStyleForActiveTarget();
    _focusRequestVersion++;
    _redoStack.clear();
    notifyListeners();
  }

  int? inlineMathSegmentIndexAtTextOffset(String nodeId, int offset) {
    final node = nodes
        .whereType<TextBlockNode>()
        .cast<TextBlockNode?>()
        .firstWhere((candidate) => candidate?.id == nodeId, orElse: () => null);
    if (node == null) {
      return null;
    }

    var cursor = 0;
    for (var i = 0; i < node.segments.length; i++) {
      final segment = node.segments[i];
      final end = cursor + segment.plainTextLength;
      if (segment.isInlineMath && offset >= cursor && offset < end) {
        return i;
      }
      cursor = end;
    }
    return null;
  }

  TextSegment? inlineMathSegmentAt(String nodeId, int segmentIndex) {
    final node = nodes
        .whereType<TextBlockNode>()
        .cast<TextBlockNode?>()
        .firstWhere((candidate) => candidate?.id == nodeId, orElse: () => null);
    if (node == null ||
        segmentIndex < 0 ||
        segmentIndex >= node.segments.length) {
      return null;
    }
    final segment = node.segments[segmentIndex];
    return segment.isInlineMath ? segment : null;
  }

  void updateInlineMathSegment(
    String nodeId,
    int segmentIndex,
    String latex,
  ) {
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1 || latex.trim().isEmpty) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! TextBlockNode ||
        segmentIndex < 0 ||
        segmentIndex >= node.segments.length ||
        !node.segments[segmentIndex].isInlineMath) {
      return;
    }

    _pushUndoState();
    final nextSegments = node.segments.toList();
    nextSegments[segmentIndex] = nextSegments[segmentIndex].copyWith(
      text: '',
      inlineMathLatex: latex.trim(),
    );
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(segments: nextSegments);
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void removeInlineMathSegment(String nodeId, int segmentIndex) {
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! TextBlockNode ||
        segmentIndex < 0 ||
        segmentIndex >= node.segments.length ||
        !node.segments[segmentIndex].isInlineMath) {
      return;
    }

    _pushUndoState();
    final nextSegments = node.segments.toList()..removeAt(segmentIndex);
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(
      segments: nextSegments.isEmpty
          ? const [TextSegment(text: '')]
          : _mergeSegments(nextSegments),
    );
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void insertParagraph({
    int? index,
    TextBlockStyle style = TextBlockStyle.paragraph,
    String text = '',
  }) {
    _pushUndoState();
    final nextNodes = nodes.toList();
    final node = TextBlockNode(
      id: _nextId(),
      style: style,
      segments: [TextSegment(text: text)],
    );
    final insertionIndex = index ?? _defaultInsertionIndex();
    nextNodes.insert(insertionIndex.clamp(0, nextNodes.length), node);
    _document = _document.copyWith(nodes: nextNodes);
    _selectedNodeId = node.id;
    _activeTextNodeId = node.id;
    _activeSelection = const TextSelection.collapsed(offset: 0);
    _rememberTextSelection(node.id, _activeSelection);
    _syncTypingStyleForActiveTarget();
    _redoStack.clear();
    notifyListeners();
  }

  void insertMath({
    required String latex,
    required MathDisplayMode displayMode,
    int? index,
  }) {
    _pushUndoState();
    final nextNodes = nodes.toList();
    final node =
        MathNode(id: _nextId(), latex: latex, displayMode: displayMode);
    final insertionIndex = index ?? _defaultInsertionIndex();
    nextNodes.insert(insertionIndex.clamp(0, nextNodes.length), node);
    _document = _document.copyWith(nodes: nextNodes);
    _selectedNodeId = node.id;
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    _activeTypingStyle = const TextSegment(text: '');
    _redoStack.clear();
    notifyListeners();
  }

  void insertList({
    required List<String> items,
    bool ordered = false,
    int? index,
  }) {
    _pushUndoState();
    final nextNodes = nodes.toList();
    final node = ListNode(
      id: _nextId(),
      items: (items.isEmpty ? const [''] : items)
          .map((item) => <TextSegment>[TextSegment(text: item)])
          .toList(),
      style: ordered ? ListStyle.ordered : ListStyle.unordered,
    );
    final insertionIndex = index ?? _defaultInsertionIndex();
    nextNodes.insert(insertionIndex.clamp(0, nextNodes.length), node);
    _document = _document.copyWith(nodes: nextNodes);
    _selectedNodeId = node.id;
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    _activeTypingStyle = const TextSegment(text: '');
    _redoStack.clear();
    notifyListeners();
  }

  void updateListNode(
    String id, {
    required List<List<TextSegment>> items,
    required ListStyle style,
  }) {
    _replaceNode(
      id,
      (node) => (node as ListNode).copyWith(
        items: items.isEmpty
            ? const [
                <TextSegment>[TextSegment(text: '')]
              ]
            : items,
        style: style,
      ),
      shouldPushHistory: false,
    );
  }

  void insertInlineMathToActiveListItem(String latex) {
    final nodeId = _activeListNodeId;
    final itemIndex = _activeListItemIndex;
    if (nodeId == null || itemIndex == null || latex.trim().isEmpty) {
      return;
    }
    insertInlineMathAtListItemSelection(
      nodeId: nodeId,
      itemIndex: itemIndex,
      selection: _activeListSelection,
      latex: latex,
    );
  }

  void insertInlineMathAtListItemSelection({
    required String nodeId,
    required int itemIndex,
    required TextSelection selection,
    required String latex,
  }) {
    if (latex.trim().isEmpty) {
      return;
    }
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! ListNode || itemIndex < 0 || itemIndex >= node.items.length) {
      return;
    }
    final item = node.items[itemIndex];
    final normalizedSelection = _normalizedSelection(selection);
    final nextItem = _mergeSegments([
      ..._sliceSegments(item, 0, normalizedSelection.start),
      _styleForInsertedText(
        item,
        preferIndex: normalizedSelection.start > 0
            ? normalizedSelection.start - 1
            : normalizedSelection.start,
      ).copyWith(text: '', inlineMathLatex: latex.trim()),
      ..._sliceSegments(item, normalizedSelection.end, _plainTextLength(item)),
    ]);

    _pushUndoState();
    final nextItems = node.items.toList();
    nextItems[itemIndex] = nextItem;
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(items: nextItems);
    _document = _document.copyWith(nodes: nextNodes);
    final caretOffset = normalizedSelection.start + 1;
    _activeListNodeId = nodeId;
    _activeListItemIndex = itemIndex;
    _activeListSelection = TextSelection.collapsed(offset: caretOffset);
    _selectedNodeId = nodeId;
    _lastListNodeId = nodeId;
    _lastListItemIndex = itemIndex;
    _lastListSelection = _activeListSelection;
    _syncTypingStyleForActiveTarget();
    _focusRequestVersion++;
    _redoStack.clear();
    notifyListeners();
  }

  int? listInlineMathSegmentIndexAtTextOffset(
    String nodeId,
    int itemIndex,
    int offset,
  ) {
    final node = nodes.whereType<ListNode?>().firstWhere(
          (candidate) => candidate?.id == nodeId,
          orElse: () => null,
        );
    if (node == null || itemIndex < 0 || itemIndex >= node.items.length) {
      return null;
    }
    var cursor = 0;
    final item = node.items[itemIndex];
    for (var i = 0; i < item.length; i++) {
      final segment = item[i];
      final end = cursor + segment.plainTextLength;
      if (segment.isInlineMath && offset >= cursor && offset < end) {
        return i;
      }
      cursor = end;
    }
    return null;
  }

  TextSegment? listInlineMathSegmentAt(
    String nodeId,
    int itemIndex,
    int segmentIndex,
  ) {
    final node = nodes.whereType<ListNode?>().firstWhere(
          (candidate) => candidate?.id == nodeId,
          orElse: () => null,
        );
    if (node == null ||
        itemIndex < 0 ||
        itemIndex >= node.items.length ||
        segmentIndex < 0 ||
        segmentIndex >= node.items[itemIndex].length) {
      return null;
    }
    final segment = node.items[itemIndex][segmentIndex];
    return segment.isInlineMath ? segment : null;
  }

  void updateListInlineMathSegment(
    String nodeId,
    int itemIndex,
    int segmentIndex,
    String latex,
  ) {
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1 || latex.trim().isEmpty) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! ListNode ||
        itemIndex < 0 ||
        itemIndex >= node.items.length ||
        segmentIndex < 0 ||
        segmentIndex >= node.items[itemIndex].length ||
        !node.items[itemIndex][segmentIndex].isInlineMath) {
      return;
    }
    _pushUndoState();
    final nextItems = node.items.toList();
    final nextItem = nextItems[itemIndex].toList();
    nextItem[segmentIndex] = nextItem[segmentIndex]
        .copyWith(text: '', inlineMathLatex: latex.trim());
    nextItems[itemIndex] = nextItem;
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(items: nextItems);
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void removeListInlineMathSegment(
    String nodeId,
    int itemIndex,
    int segmentIndex,
  ) {
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! ListNode ||
        itemIndex < 0 ||
        itemIndex >= node.items.length ||
        segmentIndex < 0 ||
        segmentIndex >= node.items[itemIndex].length ||
        !node.items[itemIndex][segmentIndex].isInlineMath) {
      return;
    }

    _pushUndoState();
    final nextItems = node.items.toList();
    final nextItem = nextItems[itemIndex].toList()..removeAt(segmentIndex);
    nextItems[itemIndex] = nextItem.isEmpty
        ? const [TextSegment(text: '')]
        : _mergeSegments(nextItem);
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(items: nextItems);
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void insertImage({
    required String url,
    String altText = '',
    double? width,
    double? height,
    ImageLayoutMode layoutMode = ImageLayoutMode.block,
    ImageTextWrap textWrapMode = ImageTextWrap.none,
    double x = 0,
    double y = 0,
    int zIndex = 0,
    double rotationDegrees = 0,
    String? anchorBlockId,
    String wrapText = '',
    List<TextSegment>? wrapSegments,
    ImageWrapAlignment wrapAlignment = ImageWrapAlignment.none,
    int? index,
  }) {
    _pushUndoState();
    final nextNodes = nodes.toList();
    final node = ImageNode(
      id: _nextId(),
      url: url,
      altText: altText,
      width: width,
      height: height,
      layoutMode: layoutMode,
      textWrapMode: textWrapMode,
      x: x,
      y: y,
      zIndex: zIndex,
      rotationDegrees: rotationDegrees,
      anchorBlockId: anchorBlockId,
      wrapSegments: wrapSegments ?? <TextSegment>[TextSegment(text: wrapText)],
      wrapAlignment: wrapAlignment,
    );
    final insertionIndex = index ?? _defaultInsertionIndex();
    nextNodes.insert(insertionIndex.clamp(0, nextNodes.length), node);
    _document = _document.copyWith(nodes: nextNodes);
    _selectedNodeId = node.id;
    _activeTextNodeId = null;
    _activeSelection = const TextSelection.collapsed(offset: -1);
    _activeTypingStyle = const TextSegment(text: '');
    _redoStack.clear();
    notifyListeners();
  }

  void updateImageNode(
    String id, {
    required String url,
    required String altText,
    double? width,
    double? height,
    ImageLayoutMode? layoutMode,
    ImageTextWrap? textWrapMode,
    double? x,
    double? y,
    int? zIndex,
    double? rotationDegrees,
    String? anchorBlockId,
    String? wrapText,
    List<TextSegment>? wrapSegments,
    ImageWrapAlignment? wrapAlignment,
  }) {
    _replaceNode(
      id,
      (node) => (node as ImageNode).copyWith(
        url: url,
        altText: altText,
        width: width,
        height: height,
        layoutMode: layoutMode,
        textWrapMode: textWrapMode,
        x: x,
        y: y,
        zIndex: zIndex,
        rotationDegrees: rotationDegrees,
        anchorBlockId: anchorBlockId,
        wrapSegments: wrapSegments ??
            (wrapText != null ? [TextSegment(text: wrapText)] : null),
        wrapAlignment: wrapAlignment,
      ),
    );
  }

  void updateFloatingImageGeometry(
    String id, {
    double? width,
    double? height,
    double? x,
    double? y,
    int? zIndex,
    double? rotationDegrees,
    String? anchorBlockId,
  }) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! ImageNode) {
      return;
    }
    if ((width == null || width == node.width) &&
        (height == null || height == node.height) &&
        (x == null || x == node.x) &&
        (y == null || y == node.y) &&
        (zIndex == null || zIndex == node.zIndex) &&
        (rotationDegrees == null || rotationDegrees == node.rotationDegrees) &&
        (anchorBlockId == null || anchorBlockId == node.anchorBlockId)) {
      return;
    }
    _replaceNode(
      id,
      (node) => (node as ImageNode).copyWith(
        width: width,
        height: height,
        x: x,
        y: y,
        zIndex: zIndex,
        rotationDegrees: rotationDegrees,
        anchorBlockId: anchorBlockId,
      ),
      shouldPushHistory: false,
    );
  }

  void updateImageWrapSegments(String id, TextEditingValue value) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! ImageNode) {
      return;
    }
    _replaceNode(
      id,
      (node) => (node as ImageNode).copyWith(
        wrapSegments: <TextSegment>[TextSegment(text: value.text)],
      ),
      shouldPushHistory: false,
    );
  }

  TextSegment? imageWrapInlineMathSegmentAt(String id, int segmentIndex) {
    final matchIndex = nodes.indexWhere((node) => node.id == id);
    if (matchIndex == -1) {
      return null;
    }
    final node = nodes[matchIndex];
    if (node is! ImageNode ||
        segmentIndex < 0 ||
        segmentIndex >= node.wrapSegments.length) {
      return null;
    }
    final segment = node.wrapSegments[segmentIndex];
    return segment.isInlineMath ? segment : null;
  }

  void updateImageWrapInlineMathSegment(
    String id,
    int segmentIndex,
    String latex,
  ) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! ImageNode ||
        segmentIndex < 0 ||
        segmentIndex >= node.wrapSegments.length) {
      return;
    }
    _pushUndoState();
    final nextSegments = node.wrapSegments.toList();
    nextSegments[segmentIndex] = nextSegments[segmentIndex]
        .copyWith(text: '', inlineMathLatex: latex.trim());
    final nextNodes = nodes.toList();
    nextNodes[index] = node.copyWith(wrapSegments: nextSegments);
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void removeImageWrapInlineMathSegment(String id, int segmentIndex) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! ImageNode ||
        segmentIndex < 0 ||
        segmentIndex >= node.wrapSegments.length ||
        !node.wrapSegments[segmentIndex].isInlineMath) {
      return;
    }

    _pushUndoState();
    final nextSegments = node.wrapSegments.toList()..removeAt(segmentIndex);
    final nextNodes = nodes.toList();
    nextNodes[index] = node.copyWith(
      wrapSegments: nextSegments.isEmpty
          ? const [TextSegment(text: '')]
          : _mergeSegments(nextSegments),
    );
    _document = _document.copyWith(nodes: nextNodes);
    _redoStack.clear();
    notifyListeners();
  }

  void updateMathNode(String id, String latex) {
    _replaceNode(id, (node) => (node as MathNode).copyWith(latex: latex));
  }

  void updateMathNodeState(
    String id, {
    required String latex,
    required MathDisplayMode displayMode,
  }) {
    _replaceNode(
      id,
      (node) =>
          (node as MathNode).copyWith(latex: latex, displayMode: displayMode),
    );
  }

  void removeNode(String id) {
    _pushUndoState();
    final nextNodes = nodes.where((node) => node.id != id).toList();
    if (nextNodes.isEmpty) {
      nextNodes.add(
        const TextBlockNode(
          id: 'node_0',
          style: TextBlockStyle.paragraph,
          segments: [TextSegment(text: '')],
        ),
      );
    }
    _document = _document.copyWith(nodes: nextNodes);
    if (_selectedNodeId == id) {
      _selectedNodeId = nextNodes.first.id;
    }
    if (_activeTextNodeId == id) {
      _activeTextNodeId = null;
      _activeSelection = const TextSelection.collapsed(offset: -1);
    }
    if (_activeListNodeId == id) {
      _activeListNodeId = null;
      _activeListItemIndex = null;
      _activeListSelection = const TextSelection.collapsed(offset: -1);
    }
    if (_activeTextNodeId == null && _activeListNodeId == null) {
      _activeTypingStyle = const TextSegment(text: '');
    }
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) {
      return;
    }
    _redoStack.add(_document);
    _document = _undoStack.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) {
      return;
    }
    _undoStack.add(_document);
    _document = _redoStack.removeLast();
    notifyListeners();
  }

  String toJsonString() {
    return _document.toJsonString();
  }

  String toHtmlString() {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is TextBlockNode) {
        final tag = switch (node.style) {
          TextBlockStyle.paragraph => 'p',
          TextBlockStyle.heading1 => 'h1',
          TextBlockStyle.heading2 => 'h2',
        };
        buffer.writeln('<$tag>${_segmentsToHtml(node.segments)}</$tag>');
      } else if (node is ListNode) {
        final tag = node.style == ListStyle.ordered ? 'ol' : 'ul';
        buffer.writeln('<$tag>');
        for (final item in node.items) {
          buffer.writeln('  <li>${_segmentsToHtml(item)}</li>');
        }
        buffer.writeln('</$tag>');
      } else if (node is ImageNode) {
        final widthAttr =
            node.width != null ? ' width="${node.width!.round()}"' : '';
        final imageTag =
            '<img src="${_escapeHtml(node.url)}" alt="${_escapeHtml(node.altText)}"$widthAttr />';
        if (node.wrapAlignment == ImageWrapAlignment.none ||
            node.wrapSegments.every((segment) =>
                segment.text.trim().isEmpty && !segment.isInlineMath)) {
          buffer.writeln(imageTag);
        } else {
          buffer.writeln(
            '<div data-node="image-wrap" data-wrap-align="${node.wrapAlignment.name}">$imageTag<p>${_segmentsToHtml(node.wrapSegments)}</p></div>',
          );
        }
      } else if (node is MathNode) {
        final tag = node.isInline ? 'span' : 'div';
        final kind = node.isInline ? 'math-inline' : 'math-block';
        final content = node.isInline
            ? '\\(${_escapeHtml(node.latex)}\\)'
            : '\\[${_escapeHtml(node.latex)}\\]';
        buffer.writeln(
          '<$tag data-node="$kind" data-latex="${_escapeHtml(node.latex)}">$content</$tag>',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  String toHtmlDocumentString({String title = 'Document'}) {
    final bodyHtml = toHtmlString();
    final documentJson = jsonEncode(_document.toJson());
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_escapeHtml(title)}</title>
    <style>
      :root {
        color-scheme: light;
      }
      body {
        margin: 0;
        padding: 20px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        font-size: 16px;
        line-height: 1.6;
        color: #1f2937;
        background: #ffffff;
        word-break: break-word;
      }
      img {
        max-width: 100%;
        height: auto;
        border-radius: 12px;
      }
      a {
        color: #0a66c2;
      }
      p, h1, h2, ul, ol, div {
        margin-top: 0;
      }
      #rte-preview {
        position: relative;
      }
      #rte-flow {
        position: relative;
        z-index: 1;
      }
      #rte-floating {
        position: absolute;
        inset: 0;
        pointer-events: none;
        z-index: 2;
      }
      .rte-node {
        margin-bottom: 12px;
      }
      .rte-heading1 {
        font-size: 30px;
        line-height: 1.25;
        font-weight: 700;
      }
      .rte-heading2 {
        font-size: 22px;
        line-height: 1.3;
        font-weight: 600;
      }
      .rte-paragraph,
      .rte-list-item {
        font-size: 16px;
        line-height: 1.4;
        font-weight: 400;
      }
      .rte-wrap-block {
        display: flex;
        gap: 16px;
        align-items: flex-start;
      }
      .rte-wrap-block.right {
        flex-direction: row-reverse;
      }
      .rte-wrap-text {
        flex: 1;
        min-width: 0;
      }
      .rte-list {
        margin: 0 0 12px 0;
        padding-left: 24px;
      }
      .rte-line {
        display: flex;
        align-items: flex-start;
        min-height: 1em;
      }
      .rte-line-block {
        display: flex;
        align-items: flex-start;
      }
      .rte-token {
        white-space: pre;
      }
      .rte-token.bold {
        font-weight: 700;
      }
      .rte-token.italic {
        font-style: italic;
      }
      .rte-token.underline {
        text-decoration: underline;
      }
      .rte-token.link {
        color: #0a66c2;
        text-decoration: underline;
      }
      .rte-floating-image {
        position: absolute;
        overflow: hidden;
        border-radius: 12px;
        background: #e5e7eb;
        box-shadow: 0 8px 24px rgba(15, 23, 42, 0.12);
      }
      .rte-block-image img {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: contain;
      }
      .rte-floating-image img {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
      .rte-block-image {
        overflow: hidden;
        border-radius: 12px;
      }
    </style>
    <script>
      window.MathJax = {
        tex: {
          inlineMath: [['\\\\(', '\\\\)']],
          displayMath: [['\\\\[', '\\\\]']]
        },
        options: {
          skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre']
        }
      };
    </script>
    <script
      id="MathJax-script"
      async
      src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js">
    </script>
  </head>
  <body>
    <div id="rte-preview">
      <div id="rte-flow"></div>
      <div id="rte-floating"></div>
    </div>
    <noscript>
$bodyHtml
    </noscript>
    <script>
      (function() {
        const preview = document.getElementById('rte-preview');
        const flowRoot = document.getElementById('rte-flow');
        const floatingRoot = document.getElementById('rte-floating');
        if (!preview || !flowRoot || !floatingRoot) {
          return;
        }

        const documentModel = $documentJson;
        const fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
        const tokenMeasureCanvas = document.createElement('canvas');
        const tokenMeasureContext = tokenMeasureCanvas.getContext('2d');

        function styleForTextBlock(style) {
          if (style === 'heading1') {
            return {
              tag: 'h1',
              className: 'rte-heading1',
              fontSize: 30,
              lineHeight: 1.25,
              fontWeight: 700
            };
          }
          if (style === 'heading2') {
            return {
              tag: 'h2',
              className: 'rte-heading2',
              fontSize: 22,
              lineHeight: 1.3,
              fontWeight: 600
            };
          }
          return {
            tag: 'p',
            className: 'rte-paragraph',
            fontSize: 16,
            lineHeight: 1.4,
            fontWeight: 400
          };
        }

        function measureToken(value, style) {
          if (!tokenMeasureContext) {
            return value.length * style.fontSize * 0.58;
          }
          tokenMeasureContext.font = style.fontWeight + ' ' + style.fontSize + 'px ' + fontFamily;
          return tokenMeasureContext.measureText(value).width;
        }

        function segmentHtml(segment) {
          if (segment.inlineMathLatex) {
            return '<span data-node="math-inline" data-latex="' + escapeHtml(segment.inlineMathLatex) + '">\\\\(' + escapeHtml(segment.inlineMathLatex) + '\\\\)</span>';
          }
          let content = escapeHtml(segment.text || '');
          if (segment.bold) {
            content = '<strong>' + content + '</strong>';
          }
          if (segment.italic) {
            content = '<em>' + content + '</em>';
          }
          if (segment.underline) {
            content = '<u>' + content + '</u>';
          }
          if (segment.link) {
            content = '<a href="' + escapeHtml(segment.link) + '">' + content + '</a>';
          }
          return content;
        }

        function segmentsHtml(segments) {
          return (segments || []).map(segmentHtml).join('');
        }

        function tokenizeSegments(segments) {
          const tokens = [];
          for (let i = 0; i < (segments || []).length; i += 1) {
            const segment = segments[i];
            if (segment.inlineMathLatex) {
              tokens.push({
                value: '\\\\(' + segment.inlineMathLatex + '\\\\)',
                bold: false,
                italic: false,
                underline: false,
                link: null
              });
              if (i !== segments.length - 1) {
                tokens.push({ value: ' ', bold: false, italic: false, underline: false, link: null });
              }
              continue;
            }
            const text = segment.text || '';
            const matches = text.match(/\\S+\\s*/g);
            if (!matches || matches.length === 0) {
              if (text.length > 0) {
                tokens.push({
                  value: text,
                  bold: !!segment.bold,
                  italic: !!segment.italic,
                  underline: !!segment.underline,
                  link: segment.link || null
                });
              }
              continue;
            }
            for (const part of matches) {
              tokens.push({
                value: part,
                bold: !!segment.bold,
                italic: !!segment.italic,
                underline: !!segment.underline,
                link: segment.link || null
              });
            }
          }
          return tokens;
        }

        function clamp(value, min, max) {
          return Math.min(Math.max(value, min), max);
        }

        function escapeHtml(value) {
          return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
        }

        function takeTokens(tokens, startIndex, width, style) {
          if (startIndex >= tokens.length || width <= 0) {
            return { accepted: [], consumed: 0 };
          }
          const accepted = [];
          let consumed = 0;
          let totalWidth = 0;
          for (let index = startIndex; index < tokens.length; index += 1) {
            const token = tokens[index];
            const tokenWidth = measureToken(token.value, style);
            if (accepted.length > 0 && totalWidth + tokenWidth > width) {
              break;
            }
            accepted.push(token);
            consumed += 1;
            totalWidth += tokenWidth;
          }
          if (consumed === 0) {
            return { accepted: [tokens[startIndex]], consumed: 1 };
          }
          return { accepted, consumed };
        }

        function buildTokenElement(token) {
          if (token.link) {
            const link = document.createElement('a');
            link.className = 'rte-token link' +
              (token.bold ? ' bold' : '') +
              (token.italic ? ' italic' : '') +
              (token.underline ? ' underline' : '');
            link.href = token.link;
            link.innerHTML = token.value.startsWith('\\\\(')
              ? token.value
              : escapeHtml(token.value);
            return link;
          }
          const span = document.createElement('span');
          span.className = 'rte-token' +
            (token.bold ? ' bold' : '') +
            (token.italic ? ' italic' : '') +
            (token.underline ? ' underline' : '');
          span.innerHTML = token.value.startsWith('\\\\(')
            ? token.value
            : escapeHtml(token.value);
          return span;
        }

        function buildWrappedLayout(segments, style, bands, width) {
          const container = document.createElement('div');
          container.className = style.className;
          const tokens = tokenizeSegments(segments);
          let tokenIndex = 0;
          let currentTop = 0;
          const lineHeightPx = style.fontSize * style.lineHeight;
          const sortedBands = [...bands].sort((a, b) => a.top - b.top);

          while (tokenIndex < tokens.length) {
            const band = sortedBands.find(function(entry) {
              return currentTop + lineHeightPx > entry.top && currentTop < entry.bottom;
            });

            if (!band) {
              const built = takeTokens(tokens, tokenIndex, width, style);
              tokenIndex += built.consumed;
              const line = document.createElement('div');
              line.className = 'rte-line';
              built.accepted.forEach(function(token) {
                line.appendChild(buildTokenElement(token));
              });
              container.appendChild(line);
              currentTop += lineHeightPx;
              continue;
            }

            const leftWidth = clamp(band.blockedStart, 0, width);
            const blockedWidth = clamp(band.blockedEnd - band.blockedStart, 0, width - leftWidth);
            const rightWidth = clamp(width - leftWidth - blockedWidth, 0, width);
            const leftBuilt = leftWidth > 48 ? takeTokens(tokens, tokenIndex, leftWidth, style) : { accepted: [], consumed: 0 };
            tokenIndex += leftBuilt.consumed;
            const rightBuilt = rightWidth > 48 ? takeTokens(tokens, tokenIndex, rightWidth, style) : { accepted: [], consumed: 0 };
            tokenIndex += rightBuilt.consumed;

            const line = document.createElement('div');
            line.className = 'rte-line-block ' + style.className;

            const left = document.createElement('div');
            left.style.width = leftWidth + 'px';
            left.style.minWidth = leftWidth + 'px';
            left.className = 'rte-line';
            leftBuilt.accepted.forEach(function(token) {
              left.appendChild(buildTokenElement(token));
            });

            const blocked = document.createElement('div');
            blocked.style.width = blockedWidth + 'px';
            blocked.style.minWidth = blockedWidth + 'px';

            const right = document.createElement('div');
            right.style.width = rightWidth + 'px';
            right.style.minWidth = rightWidth + 'px';
            right.className = 'rte-line';
            rightBuilt.accepted.forEach(function(token) {
              right.appendChild(buildTokenElement(token));
            });

            line.appendChild(left);
            line.appendChild(blocked);
            line.appendChild(right);
            container.appendChild(line);
            currentTop += lineHeightPx;
          }

          if (tokens.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'rte-line';
            empty.innerHTML = '&nbsp;';
            container.appendChild(empty);
          }

          return container;
        }

        function createFlowNode(node) {
          if (node.type === 'textBlock') {
            const element = document.createElement('div');
            element.className = 'rte-node';
            element.dataset.nodeId = node.id;
            element.dataset.nodeType = node.type;
            flowRoot.appendChild(element);
            return;
          }

          if (node.type === 'list') {
            const list = document.createElement(node.style === 'ordered' ? 'ol' : 'ul');
            list.className = 'rte-node rte-list';
            list.dataset.nodeId = node.id;
            list.dataset.nodeType = node.type;
            for (let i = 0; i < (node.items || []).length; i += 1) {
              const item = document.createElement('li');
              item.className = 'rte-list-item';
              item.dataset.nodeId = node.id + '::' + i;
              item.dataset.parentNodeId = node.id;
              item.dataset.nodeType = 'list-item';
              list.appendChild(item);
            }
            flowRoot.appendChild(list);
            return;
          }

          if (node.type === 'math') {
            const wrapper = document.createElement('div');
            wrapper.className = 'rte-node';
            wrapper.dataset.nodeId = node.id;
            wrapper.innerHTML = node.displayMode === 'inline'
              ? '<span data-node="math-inline" data-latex="' + escapeHtml(node.latex) + '">\\\\(' + escapeHtml(node.latex) + '\\\\)</span>'
              : '<div data-node="math-block" data-latex="' + escapeHtml(node.latex) + '">\\\\[' + escapeHtml(node.latex) + '\\\\]</div>';
            flowRoot.appendChild(wrapper);
            return;
          }

          if (node.type === 'image') {
            const floating = node.layoutMode === 'floating';
            if (floating) {
              return;
            }
            const wrapper = document.createElement('div');
            wrapper.className = 'rte-node';
            wrapper.dataset.nodeId = node.id;
            const dimensions = resolveBlockImageDimensions(node);
            const imageHtml = '<div class="rte-block-image" style="width:' + dimensions.width + 'px;height:' + dimensions.height + 'px"><img src="' + escapeHtml(node.url) + '" alt="' + escapeHtml(node.altText || '') + '"></div>';
            if (node.wrapAlignment && node.wrapAlignment !== 'none' && (node.wrapSegments || []).length > 0) {
              wrapper.innerHTML = '<div class="rte-wrap-block ' + (node.wrapAlignment === 'right' ? 'right' : 'left') + '">' +
                imageHtml +
                '<div class="rte-wrap-text rte-paragraph">' + segmentsHtml(node.wrapSegments) + '</div>' +
                '</div>';
            } else {
              wrapper.innerHTML = imageHtml;
            }
            flowRoot.appendChild(wrapper);
          }
        }

        function resolveBlockImageDimensions(node) {
          const width = clamp(node.width || 280, 32, 720);
          const height = clamp(node.height || (width * 0.72), 28, 320);
          return { width: width, height: height };
        }

        function renderStaticNodes() {
          flowRoot.innerHTML = '';
          floatingRoot.innerHTML = '';
          for (const node of documentModel.nodes || []) {
            createFlowNode(node);
          }
        }

        function flowRects() {
          const rects = {};
          const rootRect = preview.getBoundingClientRect();
          flowRoot.querySelectorAll('[data-node-id]').forEach(function(element) {
            const rect = element.getBoundingClientRect();
            rects[element.dataset.nodeId] = {
              left: rect.left - rootRect.left,
              top: rect.top - rootRect.top,
              width: rect.width,
              height: rect.height,
              right: rect.right - rootRect.left,
              bottom: rect.bottom - rootRect.top
            };
          });
          return rects;
        }

        function resolveAnchorRect(nodes, imageIndex, nodeRects) {
          const imageNode = nodes[imageIndex];
          if (imageNode.anchorBlockId && nodeRects[imageNode.anchorBlockId]) {
            return nodeRects[imageNode.anchorBlockId];
          }

          for (let index = imageIndex - 1; index >= 0; index -= 1) {
            const candidate = nodes[index];
            if (candidate.type === 'image' && candidate.layoutMode === 'floating') {
              continue;
            }

            const directRect = nodeRects[candidate.id];
            if (directRect) {
              return directRect;
            }

            if (candidate.type === 'list') {
              for (let itemIndex = candidate.items.length - 1; itemIndex >= 0; itemIndex -= 1) {
                const listItemRect = nodeRects[candidate.id + '::' + itemIndex];
                if (listItemRect) {
                  return listItemRect;
                }
              }
            }
          }

          return null;
        }

        function floatingRects(nodeRects) {
          const result = {};
          const nodes = documentModel.nodes || [];
          for (let index = 0; index < nodes.length; index += 1) {
            const node = nodes[index];
            if (node.type !== 'image' || node.layoutMode !== 'floating') {
              continue;
            }
            const anchor = resolveAnchorRect(nodes, index, nodeRects);
            const baseLeft = anchor ? anchor.left : 0;
            const baseTop = anchor ? anchor.top : 0;
            const width = clamp(node.width || 280, 32, 720);
            const height = clamp(node.height || (width * 0.72), 28, 720);
            result[node.id] = {
              left: baseLeft + (node.x || 0),
              top: baseTop + (node.y || 0),
              width: width,
              height: height,
              right: baseLeft + (node.x || 0) + width,
              bottom: baseTop + (node.y || 0) + height,
              node: node
            };
          }
          return result;
        }

        function renderFloatingImages(rects) {
          floatingRoot.innerHTML = '';
          let maxBottom = 0;
          Object.values(rects).sort(function(a, b) {
            return (a.node.zIndex || 0) - (b.node.zIndex || 0);
          }).forEach(function(entry) {
            const node = entry.node;
            const wrapper = document.createElement('div');
            wrapper.className = 'rte-floating-image';
            wrapper.style.left = entry.left + 'px';
            wrapper.style.top = entry.top + 'px';
            wrapper.style.width = entry.width + 'px';
            wrapper.style.height = entry.height + 'px';
            wrapper.style.zIndex = String(node.zIndex || 0);
            wrapper.style.transform = node.rotationDegrees ? 'rotate(' + node.rotationDegrees + 'deg)' : 'none';
            wrapper.innerHTML = '<img src="' + escapeHtml(node.url) + '" alt="' + escapeHtml(node.altText || '') + '">';
            floatingRoot.appendChild(wrapper);
            maxBottom = Math.max(maxBottom, entry.bottom);
          });
          preview.style.minHeight = Math.max(flowRoot.scrollHeight, maxBottom) + 'px';
        }

        function buildBands(targetRect, rects) {
          const bands = [];
          for (const entry of Object.values(rects)) {
            const overlapTop = Math.max(entry.top, targetRect.top);
            const overlapBottom = Math.min(entry.bottom, targetRect.bottom);
            if (overlapBottom <= overlapTop) {
              continue;
            }
            bands.push({
              top: overlapTop - targetRect.top,
              bottom: overlapBottom - targetRect.top,
              blockedStart: clamp(entry.left - targetRect.left, 0, targetRect.width),
              blockedEnd: clamp(entry.right - targetRect.left, 0, targetRect.width)
            });
          }
          return bands.sort(function(a, b) { return a.top - b.top; });
        }

        function rerenderTextNodes(nodeRects, rects) {
          for (const node of documentModel.nodes || []) {
            if (node.type === 'textBlock') {
              const element = flowRoot.querySelector('[data-node-id="' + CSS.escape(node.id) + '"]');
              if (!element) {
                continue;
              }
              const style = styleForTextBlock(node.style);
              const rect = nodeRects[node.id];
              if (!rect) {
                continue;
              }
              const bands = buildBands(rect, rects);
              element.innerHTML = '';
              if (bands.length === 0) {
                const tag = document.createElement(style.tag);
                tag.className = style.className;
                tag.innerHTML = segmentsHtml(node.segments);
                element.appendChild(tag);
              } else {
                element.appendChild(buildWrappedLayout(node.segments, style, bands, rect.width));
              }
            } else if (node.type === 'list') {
              for (let i = 0; i < (node.items || []).length; i += 1) {
                const itemId = node.id + '::' + i;
                const element = flowRoot.querySelector('[data-node-id="' + CSS.escape(itemId) + '"]');
                const rect = nodeRects[itemId];
                if (!element || !rect) {
                  continue;
                }
                const style = styleForTextBlock('paragraph');
                style.className = 'rte-list-item';
                const bands = buildBands(rect, rects);
                element.innerHTML = '';
                if (bands.length === 0) {
                  element.innerHTML = segmentsHtml(node.items[i]);
                } else {
                  element.appendChild(buildWrappedLayout(node.items[i], style, bands, rect.width));
                }
              }
            }
          }
        }

        function finalizeMath() {
          if (window.MathJax && window.MathJax.typesetPromise) {
            window.MathJax.typesetPromise([preview]).catch(function() {});
          }
        }

        function renderPreview() {
          renderStaticNodes();
          for (let iteration = 0; iteration < 2; iteration += 1) {
            const nodeRects = flowRects();
            const rects = floatingRects(nodeRects);
            renderFloatingImages(rects);
            rerenderTextNodes(nodeRects, rects);
          }
          renderFloatingImages(floatingRects(flowRects()));
          finalizeMath();
        }

        window.addEventListener('load', renderPreview);
        window.addEventListener('resize', renderPreview);
        renderPreview();
      })();
    </script>
  </body>
</html>
''';
  }

  String toEmbeddableHtmlString({
    String className = 'rte-viewer',
    Map<String, String> attributes = const <String, String>{},
  }) {
    final json = _escapeHtml(jsonEncode(_document.toJson()));
    final extraAttributes = attributes.entries
        .map((entry) => ' ${entry.key}="${_escapeHtml(entry.value)}"')
        .join();
    return '<div class="${_escapeHtml(className)}" data-rich-text-json="$json"$extraAttributes></div>';
  }

  void _replaceNode(
    String id,
    EditorNode Function(EditorNode node) update, {
    bool shouldPushHistory = true,
  }) {
    final index = nodes.indexWhere((node) => node.id == id);
    if (index == -1) {
      return;
    }
    if (shouldPushHistory) {
      _pushUndoState();
    }
    final nextNodes = nodes.toList();
    nextNodes[index] = update(nextNodes[index]);
    _document = _document.copyWith(nodes: nextNodes);
    if (shouldPushHistory) {
      _redoStack.clear();
    }
    notifyListeners();
  }

  void _applyInlineFormat(TextSegment Function(TextSegment segment) formatter) {
    if (_activeTextNodeId != null) {
      _applyInlineFormatToText(formatter);
      return;
    }
    if (_activeListNodeId != null && _activeListItemIndex != null) {
      _applyInlineFormatToListItem(formatter);
    }
  }

  void _applyInlineFormatToText(
    TextSegment Function(TextSegment segment) formatter,
  ) {
    final nodeId = _activeTextNodeId;
    if (nodeId == null) {
      return;
    }
    final selection = _normalizedSelection(_activeSelection);
    if (!selection.isValid) {
      return;
    }
    if (selection.isCollapsed) {
      _activeTypingStyle = formatter(_activeTypingStyle).copyWith(text: '');
      notifyListeners();
      return;
    }
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index == -1) {
      return;
    }
    final node = nodes[index];
    if (node is! TextBlockNode) {
      return;
    }

    _pushUndoState();
    final nextNodes = nodes.toList();
    nextNodes[index] = node.copyWith(
      segments: _formatSegments(node.segments, selection, formatter),
    );
    _document = _document.copyWith(nodes: nextNodes);
    _syncTypingStyleForActiveTarget();
    _redoStack.clear();
    notifyListeners();
  }

  void _applyInlineFormatToListItem(
    TextSegment Function(TextSegment segment) formatter,
  ) {
    final nodeId = _activeListNodeId;
    final itemIndex = _activeListItemIndex;
    if (nodeId == null || itemIndex == null) {
      return;
    }
    final selection = _normalizedSelection(_activeListSelection);
    if (!selection.isValid) {
      return;
    }
    if (selection.isCollapsed) {
      _activeTypingStyle = formatter(_activeTypingStyle).copyWith(text: '');
      notifyListeners();
      return;
    }
    final nodeIndex = nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex == -1) {
      return;
    }
    final node = nodes[nodeIndex];
    if (node is! ListNode || itemIndex < 0 || itemIndex >= node.items.length) {
      return;
    }

    _pushUndoState();
    final nextItems = node.items.toList();
    nextItems[itemIndex] = _formatSegments(
      nextItems[itemIndex],
      selection,
      formatter,
    );
    final nextNodes = nodes.toList();
    nextNodes[nodeIndex] = node.copyWith(items: nextItems);
    _document = _document.copyWith(nodes: nextNodes);
    _syncTypingStyleForActiveTarget();
    _redoStack.clear();
    notifyListeners();
  }

  List<TextSegment> _formatSegments(
    List<TextSegment> segments,
    TextSelection selection,
    TextSegment Function(TextSegment segment) formatter,
  ) {
    final source = segments.isEmpty ? const [TextSegment(text: '')] : segments;
    final result = <TextSegment>[];
    var cursor = 0;

    for (final segment in source) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.plainTextLength;
      cursor = segmentEnd;

      if (segment.plainTextLength == 0) {
        continue;
      }
      if (selection.end <= segmentStart || selection.start >= segmentEnd) {
        result.add(segment);
        continue;
      }

      if (segment.isInlineMath) {
        result.add(segment);
        continue;
      }

      final localStart = max(0, selection.start - segmentStart);
      final localEnd = min(segment.text.length, selection.end - segmentStart);

      if (localStart > 0) {
        result
            .add(segment.copyWith(text: segment.text.substring(0, localStart)));
      }
      if (localEnd > localStart) {
        result.add(
          formatter(
            segment.copyWith(
                text: segment.text.substring(localStart, localEnd)),
          ),
        );
      }
      if (localEnd < segment.text.length) {
        result.add(segment.copyWith(text: segment.text.substring(localEnd)));
      }
    }

    return _mergeSegments(result);
  }

  List<TextSegment> _rebuildSegmentsForTextEdit(
    List<TextSegment> segments,
    String nextText,
  ) {
    final previousText = segments.map((segment) => segment.plainText).join();
    if (previousText == nextText) {
      return segments;
    }

    var prefix = 0;
    while (prefix < previousText.length &&
        prefix < nextText.length &&
        previousText.codeUnitAt(prefix) == nextText.codeUnitAt(prefix)) {
      prefix++;
    }

    var previousSuffix = previousText.length;
    var nextSuffix = nextText.length;
    while (previousSuffix > prefix &&
        nextSuffix > prefix &&
        previousText.codeUnitAt(previousSuffix - 1) ==
            nextText.codeUnitAt(nextSuffix - 1)) {
      previousSuffix--;
      nextSuffix--;
    }

    final before = _sliceSegments(segments, 0, prefix);
    final after = _sliceSegments(segments, previousSuffix, previousText.length);
    final insertedText = nextText.substring(prefix, nextSuffix);
    final inheritedStyle = _styleForInsertedText(
      segments,
      preferIndex: prefix > 0 ? prefix - 1 : prefix,
    ).copyWith(
      text: '',
      bold: _activeTypingStyle.bold,
      italic: _activeTypingStyle.italic,
      underline: _activeTypingStyle.underline,
    );

    final middle = insertedText.isEmpty
        ? const <TextSegment>[]
        : <TextSegment>[inheritedStyle.copyWith(text: insertedText)];

    return _mergeSegments([...before, ...middle, ...after]);
  }

  List<TextSegment> _sliceSegments(
    List<TextSegment> segments,
    int start,
    int end,
  ) {
    if (start >= end) {
      return const <TextSegment>[];
    }

    final result = <TextSegment>[];
    var cursor = 0;
    for (final segment in segments) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.plainTextLength;
      cursor = segmentEnd;

      if (segmentEnd <= start ||
          segmentStart >= end ||
          segment.plainTextLength == 0) {
        continue;
      }

      if (segment.isInlineMath) {
        result.add(segment);
      } else {
        final localStart = max(0, start - segmentStart);
        final localEnd = min(segment.text.length, end - segmentStart);
        if (localEnd <= localStart) {
          continue;
        }

        result.add(
          segment.copyWith(text: segment.text.substring(localStart, localEnd)),
        );
      }
    }
    return result;
  }

  TextSegment _styleForInsertedText(
    List<TextSegment> segments, {
    required int preferIndex,
  }) {
    if (segments.isEmpty) {
      return const TextSegment(text: '');
    }

    var cursor = 0;
    for (final segment in segments) {
      final end = cursor + segment.plainTextLength;
      if (preferIndex < end) {
        return segment.copyWith(text: '', inlineMathLatex: null);
      }
      cursor = end;
    }
    return segments.last.copyWith(text: '', inlineMathLatex: null);
  }

  List<TextSegment> _mergeSegments(List<TextSegment> segments) {
    final merged = <TextSegment>[];
    for (final segment in segments) {
      if (!segment.isInlineMath && segment.text.isEmpty) {
        continue;
      }
      if (merged.isNotEmpty &&
          !merged.last.isInlineMath &&
          !segment.isInlineMath &&
          merged.last.bold == segment.bold &&
          merged.last.italic == segment.italic &&
          merged.last.underline == segment.underline &&
          merged.last.link == segment.link) {
        merged[merged.length - 1] = merged.last.copyWith(
          text: '${merged.last.text}${segment.text}',
        );
      } else {
        merged.add(segment);
      }
    }
    return merged.isEmpty ? const [TextSegment(text: '')] : merged;
  }

  int _plainTextLength(List<TextSegment> segments) {
    return segments.fold(0, (sum, segment) => sum + segment.plainTextLength);
  }

  void _pushUndoState() {
    _undoStack.add(_document);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
  }

  String _nextId() {
    return 'node_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _segmentsToHtml(List<TextSegment> segments) {
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (segment.isInlineMath) {
        buffer.write(
          '<span data-node="math-inline" data-latex="${_escapeHtml(segment.inlineMathLatex!)}">\\(${_escapeHtml(segment.inlineMathLatex!)}\\)</span>',
        );
        continue;
      }

      var content = _escapeHtml(segment.text);
      if (segment.bold) {
        content = '<strong>$content</strong>';
      }
      if (segment.italic) {
        content = '<em>$content</em>';
      }
      if (segment.underline) {
        content = '<u>$content</u>';
      }
      if (segment.hasLink) {
        content = '<a href="${_escapeHtml(segment.link!)}">$content</a>';
      }
      buffer.write(content);
    }
    return buffer.toString();
  }

  TextSelection _normalizedSelection(TextSelection selection) {
    if (!selection.isValid) {
      return selection;
    }
    final start = min(selection.baseOffset, selection.extentOffset);
    final end = max(selection.baseOffset, selection.extentOffset);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  void _rememberTextSelection(String id, TextSelection selection) {
    _lastTextNodeId = id;
    _lastTextSelection = selection;
  }

  bool _isInlineFormatActive(bool Function(TextSegment segment) predicate) {
    if (_activeTextNodeId != null) {
      return _isInlineFormatActiveInSegments(
        _segmentsForTextNode(_activeTextNodeId!),
        _normalizedSelection(_activeSelection),
        predicate,
      );
    }
    if (_activeListNodeId != null && _activeListItemIndex != null) {
      final node = nodes.whereType<ListNode?>().firstWhere(
            (candidate) => candidate?.id == _activeListNodeId,
            orElse: () => null,
          );
      if (node == null ||
          _activeListItemIndex! < 0 ||
          _activeListItemIndex! >= node.items.length) {
        return predicate(_activeTypingStyle);
      }
      return _isInlineFormatActiveInSegments(
        node.items[_activeListItemIndex!],
        _normalizedSelection(_activeListSelection),
        predicate,
      );
    }
    return predicate(_activeTypingStyle);
  }

  bool _isInlineFormatActiveInSegments(
    List<TextSegment>? segments,
    TextSelection selection,
    bool Function(TextSegment segment) predicate,
  ) {
    if (segments == null || !selection.isValid || selection.isCollapsed) {
      return predicate(_activeTypingStyle);
    }

    var hasText = false;
    var cursor = 0;
    for (final segment in segments) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.plainTextLength;
      cursor = segmentEnd;

      if (segment.plainTextLength == 0 ||
          segment.isInlineMath ||
          selection.end <= segmentStart ||
          selection.start >= segmentEnd) {
        continue;
      }

      hasText = true;
      if (!predicate(segment)) {
        return false;
      }
    }
    return hasText;
  }

  List<TextSegment>? _segmentsForTextNode(String nodeId) {
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index == -1) {
      return null;
    }
    final node = nodes[index];
    return node is TextBlockNode ? node.segments : null;
  }

  void _syncTypingStyleForActiveTarget() {
    if (_activeTextNodeId != null && _activeSelection.isValid) {
      final segments = _segmentsForTextNode(_activeTextNodeId!);
      if (segments != null) {
        _activeTypingStyle =
            _typingStyleForSelection(segments, _activeSelection);
      }
      return;
    }

    if (_activeListNodeId != null &&
        _activeListItemIndex != null &&
        _activeListSelection.isValid) {
      final node = nodes.whereType<ListNode?>().firstWhere(
            (candidate) => candidate?.id == _activeListNodeId,
            orElse: () => null,
          );
      if (node != null &&
          _activeListItemIndex! >= 0 &&
          _activeListItemIndex! < node.items.length) {
        _activeTypingStyle = _typingStyleForSelection(
          node.items[_activeListItemIndex!],
          _activeListSelection,
        );
      }
    }
  }

  TextSegment _typingStyleForSelection(
    List<TextSegment> segments,
    TextSelection selection,
  ) {
    final normalizedSelection = _normalizedSelection(selection);
    if (!normalizedSelection.isValid) {
      return _activeTypingStyle;
    }
    if (normalizedSelection.isCollapsed) {
      return _styleForInsertedText(
        segments,
        preferIndex: normalizedSelection.start > 0
            ? normalizedSelection.start - 1
            : normalizedSelection.start,
      ).copyWith(text: '');
    }

    var sawText = false;
    var bold = true;
    var italic = true;
    var underline = true;
    var cursor = 0;
    for (final segment in segments) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.plainTextLength;
      cursor = segmentEnd;

      if (segment.plainTextLength == 0 ||
          segment.isInlineMath ||
          normalizedSelection.end <= segmentStart ||
          normalizedSelection.start >= segmentEnd) {
        continue;
      }

      sawText = true;
      bold = bold && segment.bold;
      italic = italic && segment.italic;
      underline = underline && segment.underline;
    }

    if (!sawText) {
      return _activeTypingStyle;
    }

    return TextSegment(
      text: '',
      bold: bold,
      italic: italic,
      underline: underline,
    );
  }

  int _defaultInsertionIndex() {
    final anchorId = _selectedNodeId ?? _activeTextNodeId;
    if (anchorId == null) {
      return nodes.length;
    }
    final index = nodes.indexWhere((node) => node.id == anchorId);
    if (index == -1) {
      return nodes.length;
    }
    return index + 1;
  }
}
