enum DrawnGraphType {
  segmentLine,
  horizontalSegmentLine,
  verticalSegmentLine,
  rayLine,
  straightLine,
  horizontalStraightLine,
  parallelLine,
  rectangle,
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
    }
  }
}

class DrawGraphRawValue {
  double index;
  double price;

  DrawGraphRawValue(
    this.index,
    this.price,
  );
}

class DrawnGraphEntity {
  DrawnGraphType drawType;
  List<DrawGraphRawValue> values;
  bool isActive;

  DrawnGraphEntity({
    required this.drawType,
    required this.values,
    this.isActive = false,
  });
}
