// Author: Dean.Liu
// DateTime: 2022/12/08 09:57

import 'dart:ui';

class DrawGraphPresetStyles {
  /// 预设的描边颜色数组
  final List<Color> stokeColors;

  /// 预设的填充颜色数组
  final List<Color> fillColors;

  /// 预设的虚线样式数组
  final List<List<double>?> dashedLines;

  /// 预设的线宽数组
  final List<double> lineWidths;

  const DrawGraphPresetStyles({
    required this.stokeColors,
    required this.fillColors,
    required this.dashedLines,
    required this.lineWidths,
  });
}
