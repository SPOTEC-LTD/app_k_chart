import 'package:flutter/material.dart';

import '../entity/k_line_entity.dart';
import '../extension/num_ext.dart';
import '../indicator_setting.dart';
import '../k_chart_widget.dart' show SecondaryState;
import '../utils/number_util.dart';
import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<KLineEntity> {
  late double mMACDWidth;
  late double mVolWidth;
  SecondaryState state;
  final ChartStyle chartStyle;
  final ChartColors chartColors;
  final KdjSetting kdjSetting;
  final List<int> rsiDayList;
  final List<int> wrDayList;
  final MacdSetting macdSetting;
  final int cciDay;

  double get childPadding => chartStyle.childPadding;

  SecondaryRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    this.state,
    int fixedLength,
    TextStyle inheritedTextStyle,
    this.chartStyle,
    this.chartColors,
    this.kdjSetting,
    this.rsiDayList,
    this.wrDayList,
    this.macdSetting,
    this.cciDay,
  ) : super(
          chartRect: mainRect,
          maxValue: maxValue,
          minValue: minValue,
          fixedLength: fixedLength,
          gridColor: chartColors.gridColor,
          inheritedTextStyle: inheritedTextStyle,
        ) {
    mMACDWidth = this.chartStyle.macdWidth;
    mVolWidth = this.chartStyle.volWidth;
  }

  double getVolY(double value) =>
      (maxValue - value) * (chartRect.height / maxValue) + chartRect.top;

  @override
  void drawChart(KLineEntity lastPoint, KLineEntity curPoint, double lastX,
      double curX, Size size, Canvas canvas) {
    switch (state) {
      case SecondaryState.VOLUME:
        drawVolume(lastPoint, curPoint, lastX, curX, size, canvas);
        break;
      case SecondaryState.MACD:
        drawMACD(curPoint, canvas, curX, lastPoint, lastX);
        break;
      case SecondaryState.KDJ:
        drawLine(lastPoint.k, curPoint.k, canvas, lastX, curX,
            this.chartColors.getIndicatorColor(0));
        drawLine(lastPoint.d, curPoint.d, canvas, lastX, curX,
            this.chartColors.getIndicatorColor(1));
        drawLine(lastPoint.j, curPoint.j, canvas, lastX, curX,
            this.chartColors.getIndicatorColor(2));
        break;
      case SecondaryState.RSI:
        for (int i = 0; i < rsiDayList.length; i++) {
          drawLine(lastPoint.rsiValueList?[i], curPoint.rsiValueList?[i],
              canvas, lastX, curX, this.chartColors.getIndicatorColor(i));
        }
        break;
      case SecondaryState.WR:
        for (int i = 0; i < wrDayList.length; i++) {
          drawLine(lastPoint.wrValueList?[i], curPoint.wrValueList?[i], canvas,
              lastX, curX, this.chartColors.getIndicatorColor(i));
        }
        break;
      case SecondaryState.CCI:
        drawLine(lastPoint.cci, curPoint.cci, canvas, lastX, curX,
            this.chartColors.getIndicatorColor(0));
        break;
      default:
        break;
    }
  }

  void drawVolume(KLineEntity lastPoint, KLineEntity curPoint, double lastX,
      double curX, Size size, Canvas canvas) {
    double r = mVolWidth / 2;
    double top = getVolY(curPoint.vol);
    double bottom = chartRect.bottom;
    if (curPoint.vol != 0) {
      canvas.drawRect(
          Rect.fromLTRB(curX - r, top, curX + r, bottom),
          chartPaint
            ..color = curPoint.close > curPoint.open
                ? this.chartColors.upColor
                : this.chartColors.dnColor);
    }

    if (lastPoint.MA5Volume != 0) {
      drawLine(lastPoint.MA5Volume, curPoint.MA5Volume, canvas, lastX, curX,
          this.chartColors.getIndicatorColor(0));
    }

    if (lastPoint.MA10Volume != 0) {
      drawLine(lastPoint.MA10Volume, curPoint.MA10Volume, canvas, lastX, curX,
          this.chartColors.getIndicatorColor(1));
    }
  }

  void drawMACD(KLineEntity curPoint, Canvas canvas, double curX,
      KLineEntity lastPoint, double lastX) {
    final macd = curPoint.macd ?? 0;
    double macdY = getY(macd);
    double r = mMACDWidth / 2;
    double zeroy = getY(0);
    if (macd > 0) {
      canvas.drawRect(Rect.fromLTRB(curX - r, macdY, curX + r, zeroy),
          chartPaint..color = this.chartColors.upColor);
    } else {
      canvas.drawRect(Rect.fromLTRB(curX - r, zeroy, curX + r, macdY),
          chartPaint..color = this.chartColors.dnColor);
    }
    if (lastPoint.dif != 0) {
      drawLine(lastPoint.dif, curPoint.dif, canvas, lastX, curX,
          this.chartColors.getIndicatorColor(1));
    }
    if (lastPoint.dea != 0) {
      drawLine(lastPoint.dea, curPoint.dea, canvas, lastX, curX,
          this.chartColors.getIndicatorColor(2));
    }
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    List<TextSpan>? children;
    switch (state) {
      case SecondaryState.VOLUME:
        children = [
          TextSpan(
              text: "VOL:${NumberUtil.format(data.vol)}    ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
          if (data.MA5Volume.notNullOrZero)
            TextSpan(
                text: "MA5:${NumberUtil.format(data.MA5Volume!)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(0))),
          if (data.MA10Volume.notNullOrZero)
            TextSpan(
                text: "MA10:${NumberUtil.format(data.MA10Volume!)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(1))),
        ];
        break;
      case SecondaryState.MACD:
        children = [
          TextSpan(
              text:
                  "MACD(${macdSetting.short},${macdSetting.long},${macdSetting.m})    ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
          if (data.macd != 0)
            TextSpan(
                text: "MACD:${format(data.macd)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(0))),
          if (data.dif != 0)
            TextSpan(
                text: "DIF:${format(data.dif)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(1))),
          if (data.dea != 0)
            TextSpan(
                text: "DEA:${format(data.dea)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(2))),
        ];
        break;
      case SecondaryState.KDJ:
        children = [
          TextSpan(
              text:
                  "KDJ(${kdjSetting.period},${kdjSetting.m1},${kdjSetting.m2})    ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
          if (data.k != null)
            TextSpan(
                text: "K:${format(data.k)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(0))),
          if (data.d != null)
            TextSpan(
                text: "D:${format(data.d)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(1))),
          if (data.j != null)
            TextSpan(
                text: "J:${format(data.j)}    ",
                style: getTextStyle(this.chartColors.getIndicatorColor(2))),
        ];
        break;
      case SecondaryState.RSI:
        children = [
          TextSpan(
              text: "RSI(${rsiDayList.join(',')})   ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
        ];
        for (int i = 0; i < rsiDayList.length; i++) {
          if (data.rsiValueList?[i] != null) {
            var item = TextSpan(
                text: "${rsiDayList[i]}:${format(data.rsiValueList?[i])}   ",
                style: getTextStyle(this.chartColors.getIndicatorColor(i)));
            children.add(item);
          }
        }
        break;
      case SecondaryState.WR:
        children = [
          TextSpan(
              text: "WR(${wrDayList.join(',')})   ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
        ];
        for (int i = 0; i < wrDayList.length; i++) {
          if (data.wrValueList?[i] != null) {
            var item = TextSpan(
                text: "${wrDayList[i]}:${format(data.wrValueList?[i])}   ",
                style: getTextStyle(this.chartColors.getIndicatorColor(i)));
            children.add(item);
          }
        }
        break;
      case SecondaryState.CCI:
        children = [
          TextSpan(
              text: "CCI($cciDay)   ",
              style: getTextStyle(this.chartColors.indicatorDesColor)),
          if (data.cci != null)
            TextSpan(
                text: "$cciDay:${format(data.cci)}",
                style: getTextStyle(this.chartColors.getIndicatorColor(0))),
        ];
        break;
      default:
        break;
    }
    TextPainter tp = TextPainter(
        text: TextSpan(children: children ?? []),
        textDirection: TextDirection.ltr);
    tp.layout();
    final offsetY = (childPadding - tp.height) / 2;
    tp.paint(canvas, Offset(x, chartRect.top - childPadding + offsetY));
  }

  @override
  void drawVerticalText(canvas, textStyle, int gridRows) {
    String maxText;
    String minText;
    if (state == SecondaryState.VOLUME) {
      maxText = NumberUtil.format(maxValue);
      minText = '';
    } else {
      maxText = format(maxValue);
      minText = format(minValue);
    }
    TextPainter maxTp = TextPainter(
        text: TextSpan(text: "$maxText", style: textStyle),
        textDirection: TextDirection.ltr);
    maxTp.layout();
    TextPainter minTp = TextPainter(
        text: TextSpan(text: "$minText", style: textStyle),
        textDirection: TextDirection.ltr);
    minTp.layout();

    maxTp.paint(
      canvas,
      Offset(chartRect.width - maxTp.width - 6, chartRect.top - maxTp.height),
    );
    minTp.paint(
      canvas,
      Offset(
        chartRect.width - minTp.width - 6,
        chartRect.bottom - minTp.height,
      ),
    );
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(Offset(0, chartRect.top),
        Offset(chartRect.width, chartRect.top), gridPaint);
    canvas.drawLine(Offset(0, chartRect.bottom),
        Offset(chartRect.width, chartRect.bottom), gridPaint);
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 1; i < gridColumns; i++) {
      //mSecondaryRect垂直线
      canvas.drawLine(Offset(columnSpace * i, chartRect.top - childPadding),
          Offset(columnSpace * i, chartRect.bottom), gridPaint);
    }
  }
}
