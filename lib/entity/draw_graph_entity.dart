import 'dart:ui';

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
class DrawGraphRawValue {
  double price;
  double? index;
  int? time;

  DrawGraphRawValue({
    required this.price,
    this.index,
    this.time,
  });

  DrawGraphRawValue.fromMap(Map<String, dynamic> map)
      : price = map['price'],
        index = map['index'],
        time = map['time'];

  Map<String, Object?> toMap() {
    return {'price': price, 'index': index, 'time': time};
  }
}

class DrawnGraphStyle {
  /// 描边颜色
  final Color strokeColor;

  /// 填充颜色
  final Color? fillColor;

  /// 线宽
  final double lineWidth;

  /// 虚线实体、空白的宽度，不传默认为实线
  final List<double>? dashArray;

  /// 对于老版本不可自定义样式的，颜色需要有个默认值才不会解析失败
  static const placeholderColorValue = 0xFF0FB5DA;

  DrawnGraphStyle({
    required this.strokeColor,
    required this.fillColor,
    required this.lineWidth,
    this.dashArray,
  });

  DrawnGraphStyle.placeholder()
      : strokeColor = Color(placeholderColorValue),
        fillColor = Color(placeholderColorValue),
        lineWidth = 1,
        dashArray = null;

  DrawnGraphStyle.fromMap(Map<String, dynamic> map)
      : strokeColor =
            Color(map['strokeColor'] as int? ?? placeholderColorValue),
        // 给默认值是因为兼容老版本没有该参数的情况
        fillColor = Color(map['fillColor'] as int? ?? placeholderColorValue)
            .withOpacity(0.2),
        lineWidth = map['lineWidth'],
        dashArray = map['dashArray'] == null
            ? null
            : List<double>.from(map['dashArray']);

  Map<String, Object?> toMap() {
    return {
      'strokeColor': strokeColor.value,
      'fillColor': fillColor?.value,
      'lineWidth': lineWidth,
      'dashArray': dashArray,
    };
  }
}

/// 绘制图形的model，包含类型、锚点、样式、是否激活等属性
class DrawnGraphEntity {
  final DrawnGraphType drawType;
  final DrawnGraphStyle style;
  List<DrawGraphRawValue> values;
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
    this.isActive = false,
  });

  DrawnGraphEntity.fromMap(Map<String, dynamic> map)
      : drawType = DrawnGraphTypeExtension.fromJson(map['drawType']),
        values = (map['values'] as List)
            .map((e) => DrawGraphRawValue.fromMap(e))
            .toList(),
        style = map['style'] == null
            ? DrawnGraphStyle.placeholder()
            : DrawnGraphStyle.fromMap(map['style']),
        isActive = false;

  Map<String, Object?> toMap() {
    return {
      'drawType': drawType.toJson(),
      'values': values.map((e) => e.toMap()).toList(),
      'style': style.toMap(),
      'isActive': false,
    };
  }
}
