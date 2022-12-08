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

  /// 是否显示绘制的图形
  bool get showDrawnGraphs => _showDrawnGraphs;

  /// 是否显示绘制的图形
  set showDrawnGraphs(bool show) {
    _showDrawnGraphs = show;
    notifyListeners();
  }

  bool _showDrawnGraphs = true;

  /// 激活的图形
  DrawnGraphEntity? get activeGraph {
    for (var graph in _drawnGraphs) {
      if (graph.isActive) {
        return graph;
      }
    }
    return null;
  }

  VoidCallback? hideInfoDialogFunction;

  /// 隐藏信息弹窗
  void hideInfoDialog() {
    hideInfoDialogFunction?.call();
  }

  /// 将所有绘制的图形设置为未激活状态，如果图形还未绘制完，则删除该图形
  void deactivateAllDrawnGraphs() {
    if (_drawnGraphs.isNotEmpty && !_drawnGraphs.last.drawFinished) {
      _drawnGraphs.removeLast();
    }
    _drawnGraphs.forEach((graph) => graph.isActive = false);
    notifyListeners();
  }

  /// 移除绘制中的、编辑中的图形
  void removeActiveGraph() {
    _drawnGraphs.removeWhere((graph) => graph.isActive);
    notifyListeners();
  }

  /// 更新当前激活图形的样式
  void updateActiveGraphStyle({
    int? strokeColorIndex,
    int? fillColorIndex,
    int? lineWidthIndex,
    int? dashedLineIndex,
  }) {
    final active = activeGraph;
    if (active == null) return;
    active.style = active.style.copyWith(
      strokeColorIndex,
      fillColorIndex,
      lineWidthIndex,
      dashedLineIndex,
    );
    notifyListeners();
  }

  /// 切换当前激活图形是否锁定的状态
  void toggleActiveGraphLockState() {
    final active = activeGraph;
    if (active == null) return;
    active.isLocked = !active.isLocked;
    notifyListeners();
  }

  /// 移除所有绘制的图形
  void removeAllDrawnGraphs() {
    _drawnGraphs = [];
    notifyListeners();
  }
}
