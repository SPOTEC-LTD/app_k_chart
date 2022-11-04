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

class DrawnGraphEntity {
  DrawnGraphType drawType;
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
    required this.values,
    this.isActive = false,
  });

  DrawnGraphEntity.fromMap(Map<String, dynamic> map)
      : drawType = DrawnGraphTypeExtension.fromJson(map['drawType']),
        values = (map['values'] as List)
            .map((e) => DrawGraphRawValue.fromMap(e))
            .toList(),
        isActive = false;

  Map<String, Object?> toMap() {
    return {
      'drawType': drawType.toJson(),
      'values': values.map((e) => e.toMap()).toList(),
      'isActive': false,
    };
  }
}
