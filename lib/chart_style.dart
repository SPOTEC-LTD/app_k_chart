import 'package:flutter/material.dart';

const _defaultIndicatorColors = [
  Color(0xFFF856A7),
  Color(0xFF649AFF),
  Color(0xFFFFCB44),
  Color(0xFF8C5FEC),
  Color(0xFF44F4FF),
  Color(0xFFEE5151),
  Color(0xFFFF7144),
  Color(0xFF96C72E),
  Color(0xFF23B770),
  Color(0xFF114BE1),
];

class ChartColors {
  List<Color> bgColor = [Color(0xff18191d), Color(0xff18191d)];

  Color kLineColor = Color(0xff4C86CD);
  Color lineFillColor = Color(0x554C86CD);
  Color lineFillInsideColor = Color(0x00000000);

  List<Color> indicatorColors = _defaultIndicatorColors;
  Color upColor = Color(0xff4DAA90);
  Color dnColor = Color(0xffC15466);

  Color indicatorDesColor = Color(0xFF23B770);

  Color defaultTextColor = Color(0xff60738E);

  Color nowPriceTextColor = Color(0xffffffff);

  //深度颜色
  Color depthBuyColor = Color(0xff60A893);
  Color depthSellColor = Color(0xffC15866);

  //选中后显示值边框颜色
  Color selectBorderColor = Color(0xff6C7A86);

  //选中后显示值背景的填充颜色
  Color selectFillColor = Color(0xff0D1722);

  //分割线颜色
  Color gridColor = Color(0xff4c5c74);

  Color infoWindowNormalColor = Color(0xffffffff);
  Color infoWindowTitleColor = Color(0xffffffff);
  Color infoWindowUpColor = Color(0xff00ff00);
  Color infoWindowDnColor = Color(0xffff0000);

  Color hCrossColor = Color(0xffffffff);
  Color vCrossColor = Color(0x1Effffff);
  Color crossTextColor = Color(0xffffffff);

  //当前显示内最大和最小值的颜色
  Color maxColor = Color(0xffffffff);
  Color minColor = Color(0xffffffff);

  // 实时价格虚线颜色
  Color nowPriceDashLineColor = Color(0xff696969);

  Color getIndicatorColor(int index) {
    final realIndex = index % 10;
    if (realIndex > indicatorColors.length - 1) {
      return _defaultIndicatorColors[realIndex];
    } else {
      return indicatorColors[realIndex];
    }
  }
}

class ChartStyle {
  double topPadding = 30.0;

  double bottomPadding = 20.0;

  double mainVerticalPadding = 15;

  double childPadding = 12.0;

  double rightPadding = 60.0;

  //点与点的距离
  double pointWidth = 11.0;

  //蜡烛宽度
  double candleWidth = 8.5;

  //蜡烛中间线的宽度
  double candleLineWidth = 1.5;

  //vol柱子宽度
  double volWidth = 8.5;

  //macd柱子宽度
  double macdWidth = 3.0;

  //垂直交叉线宽度
  double vCrossWidth = 8.5;

  //水平交叉线宽度
  double hCrossWidth = 1;

  //水平、垂直交叉圆点大小
  double crossPointRadius = 8.5;

  //现在价格的线条长度
  double nowPriceLineLength = 1;

  //现在价格的线条间隔
  double nowPriceLineSpan = 1;

  //现在价格的线条粗细
  double nowPriceLineWidth = 1;

  int gridRows = 4;

  int gridColumns = 4;

  //下方時間客製化
  List<String>? dateTimeFormat;

  //选中后弹窗的宽度
  double? selectWidth = 100;

  //选中后弹窗的padding
  double? selectPadding = 5;

  //选中后显示值边框圆角
  double selectBorderRadius = 0;

  //选中后显示值边框宽度
  double selectBorderWidth = 1;
}
