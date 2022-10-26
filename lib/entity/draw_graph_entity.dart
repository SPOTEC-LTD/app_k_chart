enum DrawnGraphType {
  segmentLine,
  horizontalSegmentLine,
  verticalSegmentLine,
  rayLine,
  straightLine,
  horizontalStraightLine,
  parallelLine,
  rectangle,
  threeWave,
  fiveWave,
}

extension DrawnGraphTypeExtension on DrawnGraphType {
  int get anchorCount {
    switch (this) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.horizontalSegmentLine:
      case DrawnGraphType.verticalSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.rectangle:
        return 2;
      case DrawnGraphType.horizontalStraightLine:
        return 1;
      case DrawnGraphType.parallelLine:
        return 3;
      case DrawnGraphType.threeWave:
        return 4;
      case DrawnGraphType.fiveWave:
        return 6;
    }
  }
}

class DrawGraphRawValue {
  double price;
  double index;
  int? time;

  DrawGraphRawValue({
    required this.price,
    required this.index,
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
    if (drawType == DrawnGraphType.horizontalStraightLine) {
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
}
