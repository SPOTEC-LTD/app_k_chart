import 'package:flutter/material.dart';

export '../chart_style.dart';

abstract class BaseChartRenderer<T> {
  double maxValue, minValue;
  late double scaleY;
  Rect chartRect;
  int fixedLength;
  Paint chartPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..color = Colors.red;
  Paint gridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1
    ..color = Color(0xff4c5c74);
  final TextStyle inheritedTextStyle;

  BaseChartRenderer({
    required this.chartRect,
    required this.maxValue,
    required this.minValue,
    required this.fixedLength,
    required Color gridColor,
    required this.inheritedTextStyle,
  }) {
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = chartRect.height / (maxValue - minValue);
    gridPaint.color = gridColor;
    // print("maxValue=====" + maxValue.toString() + "====minValue===" + minValue.toString() + "==scaleY==" + scaleY.toString());
  }

  double getY(double price) => (maxValue - price) * scaleY + chartRect.top;

  String format(double? n) {
    if (n == null || n.isNaN) {
      return "0.00";
    } else {
      return n.toStringAsFixed(fixedLength);
    }
  }

  void drawGrid(Canvas canvas, int gridRows, int gridColumns);

  void drawText(Canvas canvas, T data, double x);

  void drawVerticalText(canvas, textStyle, int gridRows);

  void drawChart(T lastPoint, T curPoint, double lastX, double curX, Size size,
      Canvas canvas);

  void drawLine(double? lastPrice, double? curPrice, Canvas canvas,
      double lastX, double curX, Color color) {
    if (lastPrice == null || curPrice == null) {
      return;
    }
    //("lasePrice==" + lastPrice.toString() + "==curPrice==" + curPrice.toString());
    double lastY = getY(lastPrice);
    double curY = getY(curPrice);
    //print("lastX-----==" + lastX.toString() + "==lastY==" + lastY.toString() + "==curX==" + curX.toString() + "==curY==" + curY.toString());
    canvas.drawLine(
        Offset(lastX, lastY), Offset(curX, curY), chartPaint..color = color);
  }

  TextStyle getTextStyle(Color color) {
    return inheritedTextStyle.merge(
      TextStyle(
        fontSize: 9.0,
        color: color,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }
}
