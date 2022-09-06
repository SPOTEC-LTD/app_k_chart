import 'dart:async' show StreamSink;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../entity/draw_graph_entity.dart';
import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import '../utils/distance_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class TrendLine {
  final Offset p1;
  final Offset p2;
  final double maxHeight;
  final double scale;

  TrendLine(this.p1, this.p2, this.maxHeight, this.scale);
}

double? trendLineX;

double getTrendLineX() {
  return trendLineX ?? 0;
}

class ChartPainter extends BaseChartPainter {
  final List<TrendLine> lines; //For TrendLine
  final bool isTrendLine; //For TrendLine
  bool isrecordingCord = false; //For TrendLine
  final double selectY; //For TrendLine
  static get maxScrollX => BaseChartPainter.maxScrollX;
  late MainRenderer mMainRenderer;
  BaseChartRenderer? mVolRenderer, mSecondaryRenderer;
  StreamSink<InfoWindowEntity?>? sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  List<int> maDayList;
  final ChartColors chartColors;
  late Paint selectPointPaint, selectorBorderPaint, nowPricePaint;
  final ChartStyle chartStyle;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;
  final List<DrawnGraphEntity> drawnGraphs;

  final _graphDetectWidth = 5.0;

  // 可编辑的用户图形
  DrawnGraphEntity? _activeDrawnGraph;

  ChartPainter(
    this.chartStyle,
    this.chartColors, {
    required this.lines, //For TrendLine
    required this.isTrendLine, //For TrendLine
    required this.selectY, //For TrendLine
    required datas,
    required scaleX,
    required scrollX,
    required isLongPass,
    required selectX,
    isOnTap,
    isTapShowInfoDialog,
    required this.verticalTextAlignment,
    mainState,
    volHidden,
    secondaryState,
    this.sink,
    bool isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    required List<String> dateTimeFormat,
    this.drawnGraphs = const [],
  }) : super(chartStyle,
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            dateTimeFormat: dateTimeFormat,
            isLongPress: isLongPass,
            isOnTap: isOnTap,
            isTapShowInfoDialog: isTapShowInfoDialog,
            selectX: selectX,
            mainState: mainState,
            volHidden: volHidden,
            secondaryState: secondaryState,
            isLine: isLine) {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = this.chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..color = this.chartColors.selectBorderColor;
    nowPricePaint = Paint()
      ..strokeWidth = this.chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
    _activeDrawnGraph = drawnGraphs.firstWhereOrNull((graph) => graph.isActive);
  }

  @override
  void initChartRenderer() {
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainState,
      isLine,
      fixedLength,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      verticalTextAlignment,
      maDayList,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(mVolRect!, mVolMaxValue, mVolMinValue,
          mChildPadding, fixedLength, this.chartStyle, this.chartColors);
    }
    if (mSecondaryRect != null) {
      mSecondaryRenderer = SecondaryRenderer(
          mSecondaryRect!,
          mSecondaryMaxValue,
          mSecondaryMinValue,
          mChildPadding,
          secondaryState,
          fixedLength,
          chartStyle,
          chartColors);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    _painDrawnGraph(canvas);
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint();
    Gradient mBgGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: chartColors.bgColor,
    );
    Rect mainRect =
        Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding);
    canvas.drawRect(
        mainRect, mBgPaint..shader = mBgGradient.createShader(mainRect));

    if (mVolRect != null) {
      Rect volRect = Rect.fromLTRB(
          0, mVolRect!.top - mChildPadding, mVolRect!.width, mVolRect!.bottom);
      canvas.drawRect(
          volRect, mBgPaint..shader = mBgGradient.createShader(volRect));
    }

    if (mSecondaryRect != null) {
      Rect secondaryRect = Rect.fromLTRB(0, mSecondaryRect!.top - mChildPadding,
          mSecondaryRect!.width, mSecondaryRect!.bottom);
      canvas.drawRect(secondaryRect,
          mBgPaint..shader = mBgGradient.createShader(secondaryRect));
    }
    Rect dateRect =
        Rect.fromLTRB(0, size.height - mBottomPadding, size.width, size.height);
    canvas.drawRect(
        dateRect, mBgPaint..shader = mBgGradient.createShader(dateRect));
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      mSecondaryRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mSecondaryRenderer?.drawChart(
          lastPoint, curPoint, lastX, curX, size, canvas);
    }

    if ((isLongPress == true || (isTapShowInfoDialog && isOnTap)) &&
        isTrendLine == false) {
      drawCrossLine(canvas, size);
    }
    if (isTrendLine == true) drawTrendLines(canvas, size);
    canvas.restore();
  }

  @override
  void drawVerticalText(canvas) {
    var textStyle = getTextStyle(this.chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    mSecondaryRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    if (datas == null) return;

    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double x = 0.0;
    double y = 0.0;
    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);

      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);

        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(getDate(datas![index].time), null);
        y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        x = columnSpace * i - tp.width / 2;
        // Prevent date text out of canvas
        if (x < 0) x = 0;
        if (x > size.width - tp.width) x = size.width - tp.width;
        tp.paint(canvas, Offset(x, y));
      }
    }

//    double translateX = xToTranslateX(0);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStartIndex].id));
//      tp.paint(canvas, Offset(0, y));
//    }
//    translateX = xToTranslateX(size.width);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStopIndex].id));
//      tp.paint(canvas, Offset(size.width - tp.width, y));
//    }
  }

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    final validSelectY = _getValidSelectY();
    final price = mMainRenderer.getPrice(validSelectY);
    TextPainter tp = getTextPainter(
        price.toStringAsFixed(fixedLength), chartColors.crossTextColor);
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 9;
    double w2 = 4;
    double r = textHeight / 2 + w2;
    double y = validSelectY;
    double x;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = 1;
      Path path = new Path();
      path.moveTo(x, y - r);
      path.lineTo(x, y + r);
      path.lineTo(textWidth + 2 * w1, y + r);
      path.lineTo(textWidth + 2 * w1 + w2, y);
      path.lineTo(textWidth + 2 * w1, y - r);
      path.close();
      // 点击某-条k线的收盘价框
      canvas.drawPath(path, selectPointPaint);
      // 点击某-条k线的收盘价Border
      canvas.drawPath(path, selectorBorderPaint);
      // 点击某-条k线的收盘价
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 1 - 2 * w1 - w2;
      Path path = new Path();
      path.moveTo(x, y);
      path.lineTo(x + w2, y + r);
      path.lineTo(mWidth - 2, y + r);
      path.lineTo(mWidth - 2, y - r);
      path.lineTo(x + w2, y - r);
      path.close();
      canvas.drawPath(path, selectPointPaint);
      canvas.drawPath(path, selectorBorderPaint);
      // 点击某-条k线的收盘价
      tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));
    }

    TextPainter dateTp =
        getTextPainter(getDate(point.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = size.height - mBottomPadding;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }
    double baseLine = textHeight / 2;
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectPointPaint);
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectorBorderPaint);
    //长按竖线最下面显示的时间
    dateTp.paint(canvas, Offset(x - textWidth / 2, y));
    //长按显示这条数据详情
    sink?.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  /// 只可在最高最低价范围内移动
  double _getValidSelectY() {
    final minY = mMainRect.top + chartStyle.mainVerticalPadding;
    final maxY = mMainRect.bottom - chartStyle.mainVerticalPadding;
    if (selectY < minY) {
      return minY;
    }
    if (selectY > maxY) {
      return maxY;
    }
    return selectY;
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //长按显示按中的数据
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //松开显示最后一条数据
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    mSecondaryRenderer?.drawText(canvas, data, x);
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //绘制最大值和最小值
    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainLowMinValue.toStringAsFixed(fixedLength),
          chartColors.minColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainLowMinValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.minColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainHighMaxValue.toStringAsFixed(fixedLength),
          chartColors.maxColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainHighMaxValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.maxColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  @override
  void drawNowPrice(Canvas canvas) {
    if (!this.showNowPrice) {
      return;
    }

    if (datas == null) {
      return;
    }

    double value = datas!.last.close;
    double y = getMainY(value);

    //视图展示区域边界值绘制
    if (y > getMainY(mMainLowMinValue)) {
      y = getMainY(mMainLowMinValue);
    }

    if (y < getMainY(mMainHighMaxValue)) {
      y = getMainY(mMainHighMaxValue);
    }
    nowPricePaint..color = this.chartColors.nowPriceDashLineColor;
    //先画虚线
    double startX = 0;
    final max = -mTranslateX + mWidth / scaleX;
    final space =
        this.chartStyle.nowPriceLineSpan + this.chartStyle.nowPriceLineLength;
    while (startX < max) {
      canvas.drawLine(
          Offset(startX, y),
          Offset(startX + this.chartStyle.nowPriceLineLength, y),
          nowPricePaint);
      startX += space;
    }
    //再画背景和文本
    TextPainter tp = getTextPainter(
        value.toStringAsFixed(fixedLength), this.chartColors.nowPriceTextColor);

    double offsetX;
    double xPadding = 2;
    double yPadding = 2;
    switch (verticalTextAlignment) {
      case VerticalTextAlignment.left:
        offsetX = 0;
        break;
      case VerticalTextAlignment.right:
        offsetX = mWidth - tp.width - 2 * xPadding;
        break;
    }

    double top = y - tp.height / 2 - yPadding;
    canvas.drawRect(
        Rect.fromLTRB(offsetX, top, offsetX + tp.width + 2 * xPadding,
            top + tp.height + 2 * yPadding),
        nowPricePaint);
    tp.paint(canvas, Offset(offsetX + xPadding, top + yPadding));
  }

//For TrendLine
  void drawTrendLines(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    Paint paintY = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1
      ..isAntiAlias = true;
    double x = getX(index);
    trendLineX = x;

    double y = selectY;
    // getMainY(point.close);

    // k线图竖线
    canvas.drawLine(Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding), paintY);
    Paint paintX = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 1
      ..isAntiAlias = true;
    Paint paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    if (scaleX >= 1) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 15.0 * scaleX, width: 15.0),
          paint);
    } else {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 10.0, width: 10.0 / scaleX),
          paint);
    }
    if (lines.length >= 1) {
      lines.forEach((element) {
        var y1 = -((element.p1.dy - 35) / element.scale) + element.maxHeight;
        var y2 = -((element.p2.dy - 35) / element.scale) + element.maxHeight;
        var a = (trendLineMax! - y1) * trendLineScale! + trendLineContentRec!;
        var b = (trendLineMax! - y2) * trendLineScale! + trendLineContentRec!;
        var p1 = Offset(element.p1.dx, a);
        var p2 = Offset(element.p2.dx, b);
        canvas.drawLine(
            p1,
            element.p2 == Offset(-1, -1) ? Offset(x, y) : p2,
            Paint()
              ..color = Colors.yellow
              ..strokeWidth = 2);
      });
    }
  }

  ///画交叉线
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    Paint paintY = Paint()
      ..color = this.chartColors.vCrossColor
      ..strokeWidth = this.chartStyle.vCrossWidth
      ..isAntiAlias = true;
    double x = getX(index);
    double y = _getValidSelectY();
    // k线图竖线
    canvas.drawLine(Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding), paintY);

    Paint paintX = Paint()
      ..color = this.chartColors.hCrossColor
      ..strokeWidth = this.chartStyle.hCrossWidth
      ..isAntiAlias = true;
    // k线图横线
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    if (scaleX >= 1) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y),
              height: this.chartStyle.crossPointRadius * scaleX,
              width: this.chartStyle.crossPointRadius),
          paintX);
    } else {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y),
              height: this.chartStyle.crossPointRadius,
              width: this.chartStyle.crossPointRadius / scaleX),
          paintX);
    }
  }

  TextPainter getTextPainter(text, color) {
    if (color == null) {
      color = this.chartColors.defaultTextColor;
    }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);

  /// 点是否在SecondaryRect中
  bool isInSecondaryRect(Offset point) {
    return mSecondaryRect?.contains(point) ?? false;
  }

  /// 点是否在MainRect中
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }

  double getMainPrice(double y) => mMainRenderer.getPrice(y);

  final _graphPaint = Paint()
    ..strokeWidth = 1.0
    ..isAntiAlias = true
    ..color = Colors.red;

  /// 用户手动绘制的图形
  void _painDrawnGraph(Canvas canvas) {
    canvas.save();
    canvas.clipRect(mMainRect);
    // 绘制所有手画图形
    drawnGraphs.forEach((graph) {
      _drawSingleGraph(canvas, graph);
    });
    _drawGraphAnchorPoints(canvas);
    canvas.restore();
  }

  /// 绘制单个手画图形
  void _drawSingleGraph(Canvas canvas, DrawnGraphEntity? graph) {
    if (graph == null) {
      return;
    }
    var points = graph.values.map((value) {
      double dx = translateXtoX(getX(value.index));
      double dy = getMainY(value.price);
      return Offset(dx, dy);
    }).toList();
    // 两点相同则不绘制
    if (points.length < 2 || points.first == points.last) {
      return;
    }
    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
        _drawSegmentLine(canvas, points);
        break;
      case DrawnGraphType.rayLine:
        _drawRayLine(canvas, points);
        break;
      case DrawnGraphType.straightLine:
        _drawStraightLine(canvas, points);
        break;
      case DrawnGraphType.rectangle:
        _drawRectangle(canvas, points);
        break;
      default:
    }
  }

  /// 绘制激活的图形的锚点
  void _drawGraphAnchorPoints(Canvas canvas) {
    _activeDrawnGraph?.values.forEach((value) {
      double dx = translateXtoX(getX(value.index));
      double dy = getMainY(value.price);
      canvas.drawCircle(Offset(dx, dy), _graphDetectWidth, _graphPaint);
    });
  }

  /// 绘制线段
  void _drawSegmentLine(Canvas canvas, List<Offset> points) {
    canvas.drawLine(points.first, points.last, _graphPaint);
  }

  /// 绘制射线
  void _drawRayLine(Canvas canvas, List<Offset> points) {
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    Offset endPoint;
    if (p1.dx < p2.dx) {
      // 端点在画布右侧
      endPoint = rightEdgePoint;
    } else {
      // 端点在画布左侧
      endPoint = leftEdgePoint;
    }
    canvas.drawLine(p1, endPoint, _graphPaint);
  }

  /// 绘制直线
  void _drawStraightLine(Canvas canvas, List<Offset> points) {
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);
    canvas.drawLine(leftEdgePoint, rightEdgePoint, _graphPaint);
  }

  /// 绘制矩形
  void _drawRectangle(Canvas canvas, List<Offset> points) {
    var rect = Rect.fromPoints(points.first, points.last);
    canvas.drawRect(rect, _graphPaint);
  }

  /// 直线和画板左侧的交点
  Offset _getLeftEdgePoint(Offset p1, Offset p2) {
    var y = _getYPositionInLine(0, p1, p2);
    return Offset(0, y);
  }

  /// 直线和画板右侧的交点
  Offset _getRightEdgePoint(Offset p1, Offset p2) {
    var y = _getYPositionInLine(mWidth, p1, p2);
    return Offset(mWidth, y);
  }

  /// 根据x值，计算直线和画板交点的y值
  double _getYPositionInLine(double x, Offset p1, Offset p2) {
    // 直线的一般式表达式：Ax+By+C=0
    var x1 = p1.dx;
    var y1 = p1.dy;
    var x2 = p2.dx;
    var y2 = p2.dy;
    var A = y2 - y1;
    var B = x1 - x2;
    var C = x2 * y1 - x1 * y2;
    return -(A * x + C) / B;
  }

  /// 计算点击手势的点在k线图中对应的index和价格
  DrawGraphRawValue? calculateTouchRawValue(Offset touchPoint) {
    var index = getDoubleIndex(touchPoint.dx / scaleX - mTranslateX);
    var price = getMainPrice(touchPoint.dy);
    return DrawGraphRawValue(index, price);
  }

  /// 计算移动手势的点在k线图中对应的index和价格
  DrawGraphRawValue calculateMoveRawValue(Offset movePoint) {
    var index = getDoubleIndex(movePoint.dx / scaleX - mTranslateX);
    var dy = movePoint.dy;
    if (movePoint.dy < mMainRect.top) {
      dy = mMainRect.top;
    }
    if (movePoint.dy > mMainRect.bottom) {
      dy = mMainRect.bottom;
    }
    var price = getMainPrice(dy);
    return DrawGraphRawValue(index, price);
  }

  /// 根据touch点，查找离它最近的图形
  void detectDrawnGraphs(Offset touchPoint) {
    if (drawnGraphs.isEmpty) {
      return;
    }
    drawnGraphs.forEach((graph) => graph.isActive = false);
    if (_detectSingleLine(touchPoint)) {
      return;
    }
    if (_detectRectangle(touchPoint)) {
      return;
    }
  }

  /// 根据touch点查找线形，如果找到返回true
  bool _detectSingleLine(Offset touchPoint) {
    var singleLineGraphs = drawnGraphs.where((graph) {
      switch (graph.drawType) {
        case DrawnGraphType.segmentLine:
        case DrawnGraphType.rayLine:
        case DrawnGraphType.straightLine:
          return true;
        default:
          return false;
      }
    }).toList();

    var minIndex = 0;
    var minDis = double.infinity;
    for (var i = 0; i < singleLineGraphs.length; i++) {
      var distance = _distanceToSingleLine(touchPoint, singleLineGraphs[i]);
      if (distance < minDis) {
        minIndex = i;
        minDis = distance;
      }
    }
    if (minDis < _graphDetectWidth) {
      var graph = singleLineGraphs[minIndex];
      graph.isActive = true;
      _activeDrawnGraph = graph;
      return true;
    }
    return false;
  }

  /// 根据点击的点查找矩形，如果找到返回true
  bool _detectRectangle(Offset touchPoint) {
    for (var graph in drawnGraphs) {
      if (graph.drawType == DrawnGraphType.rectangle &&
          _isPointInRectangle(touchPoint, graph)) {
        graph.isActive = true;
        _activeDrawnGraph = graph;
        return true;
      }
    }
    return false;
  }

  /// 根据长按的点，查找离它最近的锚点的index
  int? detectAnchorPointIndex(Offset touchPoint) {
    if (_activeDrawnGraph == null) {
      return null;
    }
    var anchorValues = _activeDrawnGraph!.values;
    var minIndex = 0;
    var minDis = double.infinity;
    for (var i = 0; i < anchorValues.length; i++) {
      var distance = _distanceToGraphAnchorPoint(touchPoint, anchorValues[i]);
      if (distance < minDis) {
        minIndex = i;
        minDis = distance;
      }
    }
    if (minDis < _graphDetectWidth) {
      return minIndex;
    }
    return null;
  }

  /// 根据长按开始点计算编辑中图形是否可以移动
  bool canBeginMoveActiveGraph(Offset touchPoint) {
    if (_activeDrawnGraph == null) {
      return false;
    }
    switch (_activeDrawnGraph!.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
        var distance = _distanceToSingleLine(touchPoint, _activeDrawnGraph!);
        return distance < _graphDetectWidth;
      case DrawnGraphType.rectangle:
        return _isPointInRectangle(touchPoint, _activeDrawnGraph!);
      default:
        return false;
    }
  }

  /// 是否有激活中的手画图形
  bool haveActiveDrawnGraph() {
    return _activeDrawnGraph != null;
  }

  /// 移动手画图形。如果anchorIndex为null，移动整个图形；如果不为null，则移动单个锚点
  void moveActiveGraph(DrawGraphRawValue currentValue,
      DrawGraphRawValue nextValue, int? anchorIndex) {
    // 计算和上一个点的偏移
    var offset = Offset(nextValue.index - currentValue.index,
        nextValue.price - currentValue.price);
    if (anchorIndex == null) {
      _activeDrawnGraph?.values.forEach((value) {
        value.index += offset.dx;
        value.price += offset.dy;
      });
    } else {
      _activeDrawnGraph!.values[anchorIndex].index += offset.dx;
      _activeDrawnGraph!.values[anchorIndex].price += offset.dy;
    }
  }

  /// 点是否在矩形中
  bool _isPointInRectangle(Offset touchPoint, DrawnGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(translateXtoX(getX(value1.index)), getMainY(value1.price));
    var p2 = Offset(translateXtoX(getX(value2.index)), getMainY(value2.price));
    var valueRect = Rect.fromPoints(p1, p2).inflate(_graphDetectWidth);
    return valueRect.contains(touchPoint);
  }

  /// 点到线形的距离
  double _distanceToSingleLine(Offset touchPoint, DrawnGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(translateXtoX(getX(value1.index)), getMainY(value1.price));
    var p2 = Offset(translateXtoX(getX(value2.index)), getMainY(value2.price));
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
        return DistanceUtil.distanceToSegment(touchPoint, p1, p2);
      case DrawnGraphType.rayLine:
        if (p1.dx < p2.dx) {
          // 端点在画布右侧
          return DistanceUtil.distanceToSegment(touchPoint, p1, rightEdgePoint);
        } else {
          // 端点在画布左侧
          return DistanceUtil.distanceToSegment(touchPoint, leftEdgePoint, p1);
        }
      case DrawnGraphType.straightLine:
        return DistanceUtil.distanceToSegment(
            touchPoint, leftEdgePoint, rightEdgePoint);
      default:
        return double.infinity;
    }
  }

  /// 点到各种形状的锚点的距离
  double _distanceToGraphAnchorPoint(
      Offset touchPoint, DrawGraphRawValue anchorValue) {
    var anchorPoint = Offset(
        translateXtoX(getX(anchorValue.index)), getMainY(anchorValue.price));
    return DistanceUtil.distanceToPoint(touchPoint, anchorPoint);
  }
}
