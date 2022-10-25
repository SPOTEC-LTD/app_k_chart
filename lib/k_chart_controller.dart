// Author: Dean.Liu
// DateTime: 2022/03/17 13:50

import 'package:flutter/cupertino.dart';

import 'entity/draw_graph_entity.dart';

class KChartController extends ChangeNotifier {
  KChartController({
    List<DrawnGraphEntity> drawnGraphs = const [],
  }) : _drawnGraphs = drawnGraphs;

  /// 已经绘制好的图形
  List<DrawnGraphEntity> get drawnGraphs => _drawnGraphs;

  /// 已经绘制好的图形
  set drawnGraphs(List<DrawnGraphEntity> graphs) {
    _drawnGraphs = graphs;
    notifyListeners();
  }

  List<DrawnGraphEntity> _drawnGraphs;

  /// 绘制图形的类型
  DrawnGraphType? get drawType => _drawType;

  /// 绘制图形的类型
  set drawType(DrawnGraphType? type) {
    _drawType = type;
    if (type != null) {
      deactivateAllDrawnGraphs();
    }
  }

  DrawnGraphType? _drawType;

  /// 是否存在激活的图形
  bool get existActiveGraph => _drawnGraphs.any((element) => element.isActive);

  /// 隐藏信息弹窗
  void hideInfoDialog() {
    notifyListeners();
  }

  /// 将所有绘制的图形设置为未激活状态，如果图形还未绘制完，则删除该图形
  void deactivateAllDrawnGraphs() {
    if (drawnGraphs.isNotEmpty && !drawnGraphs.last.drawFinished) {
      drawnGraphs.removeLast();
    }
    drawnGraphs.forEach((graph) => graph.isActive = false);
    notifyListeners();
  }

  /// 移除绘制中的、编辑中的图形
  void removeActiveGraph() {
    _drawType = null;
    drawnGraphs.removeWhere((graph) => graph.isActive);
    notifyListeners();
  }

  /// 移除所有绘制的图形
  void removeAllDrawnGraphs() {
    _drawType = null;
    drawnGraphs = [];
    notifyListeners();
  }
}
