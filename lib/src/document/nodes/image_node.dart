import 'package:rich_text_editor/src/document/editor_node.dart';
import 'package:rich_text_editor/src/document/text_segment.dart';

enum ImageLayoutMode { block, floating }

enum ImageTextWrap { none, around }

enum ImageWrapAlignment { none, left, right }

class ImageNode extends EditorNode {
  const ImageNode({
    required super.id,
    required this.url,
    required this.altText,
    this.width,
    this.height,
    this.layoutMode = ImageLayoutMode.block,
    this.textWrapMode = ImageTextWrap.none,
    this.x = 0,
    this.y = 0,
    this.zIndex = 0,
    this.rotationDegrees = 0,
    this.anchorBlockId,
    this.anchorTextOffset,
    this.anchorListItemIndex,
    this.wrapSegments = const [TextSegment(text: '')],
    this.wrapAlignment = ImageWrapAlignment.none,
  });

  static const String nodeType = 'image';

  final String url;
  final String altText;
  final double? width;
  final double? height;
  final ImageLayoutMode layoutMode;
  final ImageTextWrap textWrapMode;
  final double x;
  final double y;
  final int zIndex;
  final double rotationDegrees;
  final String? anchorBlockId;
  final int? anchorTextOffset;
  final int? anchorListItemIndex;
  final List<TextSegment> wrapSegments;
  final ImageWrapAlignment wrapAlignment;

  String get wrapText => wrapSegments.map((segment) => segment.text).join();

  @override
  String get type => nodeType;

  ImageNode copyWith({
    String? id,
    String? url,
    String? altText,
    double? width,
    double? height,
    ImageLayoutMode? layoutMode,
    ImageTextWrap? textWrapMode,
    double? x,
    double? y,
    int? zIndex,
    double? rotationDegrees,
    String? anchorBlockId,
    int? anchorTextOffset,
    int? anchorListItemIndex,
    List<TextSegment>? wrapSegments,
    ImageWrapAlignment? wrapAlignment,
  }) {
    return ImageNode(
      id: id ?? this.id,
      url: url ?? this.url,
      altText: altText ?? this.altText,
      width: width ?? this.width,
      height: height ?? this.height,
      layoutMode: layoutMode ?? this.layoutMode,
      textWrapMode: textWrapMode ?? this.textWrapMode,
      x: x ?? this.x,
      y: y ?? this.y,
      zIndex: zIndex ?? this.zIndex,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      anchorBlockId: anchorBlockId ?? this.anchorBlockId,
      anchorTextOffset: anchorTextOffset ?? this.anchorTextOffset,
      anchorListItemIndex: anchorListItemIndex ?? this.anchorListItemIndex,
      wrapSegments: List<TextSegment>.unmodifiable(
        wrapSegments ?? this.wrapSegments,
      ),
      wrapAlignment: wrapAlignment ?? this.wrapAlignment,
    );
  }

  factory ImageNode.fromJson(Map<String, dynamic> json) {
    return ImageNode(
      id: json['id'] as String,
      url: json['url'] as String? ?? '',
      altText: json['altText'] as String? ?? '',
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      layoutMode: json['layoutMode'] == null
          ? ImageLayoutMode.block
          : ImageLayoutMode.values.byName(json['layoutMode'] as String),
      textWrapMode: json['textWrapMode'] == null
          ? (((json['wrapAlignment'] as String?) ?? 'none') == 'none'
              ? ImageTextWrap.none
              : ImageTextWrap.around)
          : ImageTextWrap.values.byName(json['textWrapMode'] as String),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
      anchorBlockId: json['anchorBlockId'] as String?,
      anchorTextOffset: (json['anchorTextOffset'] as num?)?.toInt(),
      anchorListItemIndex: (json['anchorListItemIndex'] as num?)?.toInt(),
      wrapSegments: List<TextSegment>.unmodifiable(
        ((json['wrapSegments'] as List<dynamic>?) ??
                <dynamic>[
                  <String, dynamic>{'text': json['wrapText'] as String? ?? ''}
                ])
            .map((segment) =>
                TextSegment.fromJson(segment as Map<String, dynamic>))
            .toList(),
      ),
      wrapAlignment: json['wrapAlignment'] == null
          ? ImageWrapAlignment.none
          : ImageWrapAlignment.values.byName(json['wrapAlignment'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'url': url,
      'altText': altText,
      'width': width,
      'height': height,
      'layoutMode': layoutMode.name,
      'textWrapMode': textWrapMode.name,
      'x': x,
      'y': y,
      'zIndex': zIndex,
      'rotationDegrees': rotationDegrees,
      'anchorBlockId': anchorBlockId,
      'anchorTextOffset': anchorTextOffset,
      'anchorListItemIndex': anchorListItemIndex,
      'wrapText': wrapText,
      'wrapSegments': wrapSegments.map((segment) => segment.toJson()).toList(),
      'wrapAlignment': wrapAlignment.name,
    };
  }
}
