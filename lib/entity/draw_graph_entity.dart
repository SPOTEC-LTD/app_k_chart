enum DrawnGraphType {
  segmentLine,
  rayLine,
  straightLine,
  rectangle,
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
