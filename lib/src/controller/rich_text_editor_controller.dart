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
    _applyInlineFormat((segment) => segment.copyWith(bold: !segment.bold));
  }

  void applyItalicToSelection() {
    _applyInlineFormat((segment) => segment.copyWith(italic: !segment.italic));
  }

  void applyUnderlineToSelection() {
    _applyInlineFormat(
      (segment) => segment.copyWith(underline: !segment.underline),
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
        buffer.writeln(
          '<$tag data-node="$kind" data-latex="${_escapeHtml(node.latex)}"></$tag>',
        );
      }
    }
    return buffer.toString().trimRight();
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
    final nodeId = _activeTextNodeId;
    if (nodeId == null) {
      return;
    }
    final selection = _normalizedSelection(_activeSelection);
    if (!selection.isValid || selection.isCollapsed) {
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
          '<span data-node="math-inline" data-latex="${_escapeHtml(segment.inlineMathLatex!)}"></span>',
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
