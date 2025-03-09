import 'dart:async' show StreamSink;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../indicator_setting.dart';
import '../k_chart_widget.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';

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
  List<BaseChartRenderer> mSecondaryRenderers = [];
  StreamSink<InfoWindowEntity?>? sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  final IndicatorSetting indicatorSetting;
  final ChartColors chartColors;
  late Paint selectPointPaint;
  final ChartStyle chartStyle;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;

  final ui.Image? logoImage;

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
    required super.inheritedTextStyle,
    isOnTap,
    isTapShowInfoDialog,
    required this.verticalTextAlignment,
    MainState mainState = MainState.MA,
    volHidden,
    List<SecondaryState> secondaryStates = const [SecondaryState.VOLUME],
    this.sink,
    bool isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.indicatorSetting = const IndicatorSetting(),
    required List<String> dateTimeFormat,
    this.logoImage,
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
            secondaryStates: secondaryStates,
            isLine: isLine) {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = this.chartColors.crossLineColor;
  }

  @override
  void initChartRenderer() {
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mainState,
      isLine,
      fixedLength,
      inheritedTextStyle,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      verticalTextAlignment,
      indicatorSetting.maDayList,
      indicatorSetting.emaDayList,
      indicatorSetting.bollSetting,
    );
    mSecondaryRenderers.clear();
    for (int i = 0; i < mSecondaryRects.length; i++) {
      final mSecondaryRect = mSecondaryRects[i];
      final mSecondaryMaxValue = mSecondaryMaxValues[i];
      final mSecondaryMinValue = mSecondaryMinValues[i];
      final secondaryState = secondaryStates[i];
      final mSecondaryRenderer = SecondaryRenderer(
        mSecondaryRect,
        mSecondaryMaxValue,
        mSecondaryMinValue,
        secondaryState,
        fixedLength,
        inheritedTextStyle,
        chartStyle,
        chartColors,
        indicatorSetting.kdjSetting,
        indicatorSetting.rsiDayList,
        indicatorSetting.wrDayList,
        indicatorSetting.macdSetting,
        indicatorSetting.cciDay,
      );
      mSecondaryRenderers.add(mSecondaryRenderer);
    }
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

    for (int i = 0; i < mSecondaryRects.length; i++) {
      final mSecondaryRect = mSecondaryRects[i];
      Rect secondaryRect = Rect.fromLTRB(0, mSecondaryRect.top - mChildPadding,
          mSecondaryRect.width, mSecondaryRect.bottom);
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
      mSecondaryRenderers.forEach((render) {
        render.drawGrid(canvas, mGridRows, mGridColumns);
      });
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
      mSecondaryRenderers.forEach((render) {
        render.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      });
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
    mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    mSecondaryRenderers.forEach((render) {
      render.drawVerticalText(canvas, textStyle, mGridRows);
    });
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
      price.toStringAsFixed(fixedLength),
      chartColors.crossTextColor,
    );
    double textWidth = tp.width;

    double y = validSelectY;
    double x;
    double xPadding = 4;
    double yPadding = 2;
    double priceOriginY = y - tp.height / 2 - yPadding;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = 3;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          priceOriginY,
          tp.width + 2 * xPadding,
          tp.height + 2 * yPadding,
        ),
        Radius.circular(2),
      );
      canvas.drawRRect(rect, selectPointPaint);
      tp.paint(canvas, Offset(x + xPadding, priceOriginY + yPadding));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 2 * xPadding - 3;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          priceOriginY,
          tp.width + 2 * xPadding,
          tp.height + 2 * yPadding,
        ),
        Radius.circular(2),
      );
      canvas.drawRRect(rect, selectPointPaint);
      // 点击某-条k线的收盘价
      tp.paint(canvas, Offset(x + xPadding, priceOriginY + yPadding));
    }

    TextPainter dateTp =
        getTextPainter(getDate(point.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    x = translateXtoX(getX(index));
    y = size.height - mBottomPadding;

    if (x < textWidth + 2 * xPadding) {
      x = textWidth / 2 + xPadding + 3;
    } else if (mWidth - x < textWidth + 2 * xPadding) {
      x = mWidth - 1 - textWidth / 2 - xPadding;
    }
    final maxHeight = min(mBottomPadding, dateTp.height + yPadding * 2);
    final dateYPadding = (maxHeight - dateTp.height) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - textWidth / 2 - xPadding,
          y,
          textWidth + xPadding * 2,
          maxHeight,
        ),
        Radius.circular(2),
      ),
      selectPointPaint,
    );
    //长按竖线最下面显示的时间
    dateTp.paint(canvas, Offset(x - textWidth / 2, y + dateYPadding));
    //长按显示这条数据详情
    sink?.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  @override
  void drawLogo(Canvas canvas, Size size) {
    if (logoImage == null) return;
    mMainRenderer.drawLogo(canvas, size, logoImage!);
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
    mSecondaryRenderers.forEach((render) {
      render.drawText(canvas, data, x);
    });
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
    if (!this.showNowPrice || datas == null) {
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
    //先画虚线
    _drawDashLine(
      canvas,
      isHorizontal: true,
      dashWidth: chartStyle.nowPriceLineLength,
      dashSpace: chartStyle.nowPriceLineSpan,
      strokeWidth: chartStyle.nowPriceLineWidth,
      maxLength: mWidth,
      color: this.chartColors.nowPriceDashLineColor,
      startPoint: Offset(0, y),
    );
    //再画背景和文本
    TextPainter tp = getTextPainter(
      value.toStringAsFixed(fixedLength),
      this.chartColors.nowPriceTextColor,
    );
    double offsetX;
    double xPadding = 4;
    double yPadding = 2;
    switch (verticalTextAlignment) {
      case VerticalTextAlignment.left:
        offsetX = 3;
        break;
      case VerticalTextAlignment.right:
        offsetX = mWidth - tp.width - 2 * xPadding - 3;
        break;
    }

    double top = y - tp.height / 2 - yPadding;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offsetX,
        top,
        tp.width + 2 * xPadding,
        tp.height + 2 * yPadding,
      ),
      Radius.circular(2),
    );
    final tagPaint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..color = this.chartColors.nowPriceDashLineColor;
    canvas.drawRRect(rect, tagPaint);
    tagPaint.style = PaintingStyle.fill;
    canvas.drawRRect(rect, tagPaint);
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
    double x = getX(index);
    double y = _getValidSelectY();
    _drawDashLine(
      canvas,
      isHorizontal: false,
      dashWidth: chartStyle.crossLineLength,
      dashSpace: chartStyle.crossLineSpan,
      strokeWidth: chartStyle.crossLineWidth,
      maxLength: size.height - mBottomPadding,
      color: chartColors.crossLineColor,
      startPoint: Offset(x, mTopPadding),
    );
    Paint paintX = Paint()
      ..color = this.chartColors.crossLineColor
      ..strokeWidth = this.chartStyle.crossLineWidth
      ..isAntiAlias = true;
    _drawDashLine(
      canvas,
      isHorizontal: true,
      dashWidth: chartStyle.crossLineLength,
      dashSpace: chartStyle.crossLineSpan,
      strokeWidth: chartStyle.crossLineWidth,
      maxLength: mWidth - mTranslateX,
      color: chartColors.crossLineColor,
      startPoint: Offset(-mTranslateX, y),
    );
    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          height: this.chartStyle.crossPointRadius * scaleX,
          width: this.chartStyle.crossPointRadius,
        ),
        paintX,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          height: this.chartStyle.crossPointRadius,
          width: this.chartStyle.crossPointRadius / scaleX,
        ),
        paintX,
      );
    }
  }

  /// 绘制虚线
  void _drawDashLine(
    Canvas canvas, {
    required bool isHorizontal,
    required double dashWidth,
    required double dashSpace,
    required double strokeWidth,
    required double maxLength,
    required Color color,
    required Offset startPoint,
  }) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    Path path = Path();
    path.moveTo(startPoint.dx, startPoint.dy); // 起始点
    final startI = isHorizontal ? startPoint.dx : startPoint.dy;
    for (double i = startI; i < maxLength; i += dashWidth + dashSpace) {
      if (isHorizontal) {
        path.lineTo(i + dashWidth, startPoint.dy);
        path.moveTo(i + dashWidth + dashSpace, startPoint.dy);
      } else {
        path.lineTo(startPoint.dx, i + dashWidth);
        path.moveTo(startPoint.dx, i + dashWidth + dashSpace);
      }
    }
    canvas.drawPath(path, paint);
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
    return mSecondaryRects.any((rect) => rect.contains(point));
  }

  /// 点是否在MainRect中
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }
}
