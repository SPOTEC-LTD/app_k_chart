import 'dart:ui';

import 'package:k_chart/entity/draw_graph_preset_styles.dart';

enum DrawnGraphType {
  segmentLine,
  hSegmentLine,
  vSegmentLine,
  rayLine,
  straightLine,
  hStraightLine,
  parallelLine,
  rectangle,
  threeWave,
  fiveWave,
}

extension DrawnGraphTypeExtension on DrawnGraphType {
  int get anchorCount {
    switch (this) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.hSegmentLine:
      case DrawnGraphType.vSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.rectangle:
        return 2;
      case DrawnGraphType.hStraightLine:
        return 1;
      case DrawnGraphType.parallelLine:
        return 3;
      case DrawnGraphType.threeWave:
        return 4;
      case DrawnGraphType.fiveWave:
        return 6;
    }
  }

  String toJson() => name;

  static DrawnGraphType fromJson(String json) =>
      DrawnGraphType.values.byName(json);
}

/// 绘制图形的锚点
class DrawGraphAnchor {
  /// 价格
  double price;

  /// 根据时间戳计算出来的横坐标
  double? index;

  /// 时间戳
  int? time;

  DrawGraphAnchor({
    required this.price,
    this.index,
    this.time,
  });

  DrawGraphAnchor.fromMap(Map<String, dynamic> map)
      : price = map['price'],
        index = map['index'],
        time = map['time'];

  Map<String, Object?> toMap() {
    return {'price': price, 'index': index, 'time': time};
  }
}

class DrawnGraphStyle {
  /// 保存的描边颜色index
  final int strokeColorIndex;

  /// 保存的填充颜色index
  final int fillColorIndex;

  /// 保存的线宽index
  final int lineWidthIndex;

  /// 保存的虚线样式index
  final int dashedLineIndex;

  /// 描边颜色
  Color strokeColorFromPreset(DrawGraphPresetStyles preset) {
    if (strokeColorIndex > preset.stokeColors.length - 1) {
      return preset.stokeColors.last;
    } else {
      return preset.stokeColors[strokeColorIndex];
    }
  }

  /// 填充颜色
  Color fillColorFromPreset(DrawGraphPresetStyles preset) {
    if (fillColorIndex > preset.fillColors.length - 1) {
      return preset.fillColors.last;
    } else {
      return preset.fillColors[fillColorIndex];
    }
  }

  /// 线宽
  double lineWidthFromPreset(DrawGraphPresetStyles preset) {
    if (lineWidthIndex > preset.lineWidths.length - 1) {
      return preset.lineWidths.last;
    } else {
      return preset.lineWidths[lineWidthIndex];
    }
  }

  /// 虚线样式
  List<double>? dashedLineFromPreset(DrawGraphPresetStyles preset) {
    if (dashedLineIndex > preset.dashedLines.length - 1) {
      return preset.dashedLines.last;
    } else {
      return preset.dashedLines[dashedLineIndex];
    }
  }

  const DrawnGraphStyle({
    required this.strokeColorIndex,
    required this.fillColorIndex,
    required this.lineWidthIndex,
    required this.dashedLineIndex,
  });

  DrawnGraphStyle.placeholder()
      : strokeColorIndex = 0,
        fillColorIndex = 0,
        lineWidthIndex = 0,
        dashedLineIndex = 0;

  DrawnGraphStyle.fromMap(Map<String, dynamic> map)
      : strokeColorIndex = map['strokeColorIndex'] ?? 0,
        fillColorIndex = map['fillColorIndex'] ?? 0,
        lineWidthIndex = map['lineWidthIndex'] ?? 0,
        dashedLineIndex = map['dashedLineIndex'] ?? 0;

  Map<String, Object?> toMap() {
    return {
      'strokeColorIndex': strokeColorIndex,
      'fillColorIndex': fillColorIndex,
      'lineWidthIndex': lineWidthIndex,
      'dashedLineIndex': dashedLineIndex,
    };
  }

  DrawnGraphStyle copyWith(
    int? strokeColorIndex,
    int? fillColorIndex,
    int? lineWidthIndex,
    int? dashedLineIndex,
  ) {
    return DrawnGraphStyle(
      strokeColorIndex: strokeColorIndex ?? this.strokeColorIndex,
      fillColorIndex: fillColorIndex ?? this.fillColorIndex,
      lineWidthIndex: lineWidthIndex ?? this.lineWidthIndex,
      dashedLineIndex: dashedLineIndex ?? this.dashedLineIndex,
    );
  }
}

/// 绘制图形的model，包含类型、锚点、样式、是否激活等属性
class DrawnGraphEntity {
  /// 图形的类型
  final DrawnGraphType drawType;

  /// 图形的样式
  DrawnGraphStyle style;

  /// 图形的各个锚点
  List<DrawGraphAnchor> values;

  /// 图形是否可以移动
  bool isLocked;

  /// 图形是否激活中
  bool isActive;

  /// 当前图形是否绘制完成
  bool get drawFinished {
    if (drawType == DrawnGraphType.hStraightLine) {
      return values.length == 2;
    } else {
      return drawType.anchorCount == values.length;
    }
  }

  DrawnGraphEntity({
    required this.drawType,
    required this.style,
    required this.values,
    this.isLocked = false,
    this.isActive = false,
  });

  DrawnGraphEntity.fromMap(Map<String, dynamic> map)
      : drawType = DrawnGraphTypeExtension.fromJson(map['drawType']),
        values = (map['values'] as List)
            .map((e) => DrawGraphAnchor.fromMap(e))
            .toList(),
        style = map['style'] == null
            ? DrawnGraphStyle.placeholder()
            : DrawnGraphStyle.fromMap(map['style']),
        isLocked = map['locked'] ?? false,
        isActive = false;

  Map<String, Object?> toMap() {
    return {
      'drawType': drawType.toJson(),
      'values': values.map((e) => e.toMap()).toList(),
      'style': style.toMap(),
      'locked': isLocked,
      'isActive': false,
    };
  }
}
