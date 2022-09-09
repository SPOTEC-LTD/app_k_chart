// Author: Dean.Liu
// DateTime: 2022/09/06 15:50

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:k_chart/renderer/index.dart';

import '../entity/draw_graph_entity.dart';
import '../utils/distance_util.dart';

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.chartPainter,
    required this.drawnGraphs,
  }) : _activeDrawnGraph =
            drawnGraphs.firstWhereOrNull((graph) => graph.isActive);

  final ChartPainter chartPainter;
  final List<DrawnGraphEntity> drawnGraphs;

  Rect get mMainRect => chartPainter.mMainRect;

  double get mWidth => chartPainter.mWidth;

  double get scaleX => chartPainter.scaleX;

  double get mTranslateX => chartPainter.mTranslateX;

  final _graphPaint = Paint()
    ..strokeWidth = 1.0
    ..isAntiAlias = true
    ..color = Colors.red;

  /// 判断激活哪个图形时，添加的外边距
  final _graphDetectWidth = 5.0;

  /// 可编辑的用户图形
  DrawnGraphEntity? _activeDrawnGraph;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(mMainRect);
    // 绘制所有手画图形
    drawnGraphs.forEach((graph) {
      _drawSingleGraph(canvas, graph);
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  /// 绘制单个手画图形
  void _drawSingleGraph(Canvas canvas, DrawnGraphEntity? graph) {
    if (graph == null) {
      return;
    }
    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.horizontalSegmentLine:
      case DrawnGraphType.verticalSegmentLine:
        _drawSegmentLine(canvas, graph);
        break;
      case DrawnGraphType.rayLine:
        _drawRayLine(canvas, graph);
        break;
      case DrawnGraphType.straightLine:
      case DrawnGraphType.horizontalStraightLine:
        _drawStraightLine(canvas, graph);
        break;
      case DrawnGraphType.rectangle:
        _drawRectangle(canvas, graph);
        break;
      default:
    }
    _drawActiveAnchorPoints(canvas, graph);
  }

  /// 获取图形的锚点
  List<Offset> _getAnchorPoints(DrawnGraphEntity graph) {
    return graph.values.map((value) {
      double dx = _translateIndexToX(value.index);
      double dy = chartPainter.getMainY(value.price);
      return Offset(dx, dy);
    }).toList();
  }

  /// 绘制激活的图形的锚点
  void _drawActiveAnchorPoints(Canvas canvas, DrawnGraphEntity graph) {
    if (!graph.isActive) return;
    final points = _getAnchorPoints(graph);
    // 水平直线只显示一个锚点
    if (graph.drawType == DrawnGraphType.horizontalStraightLine) {
      points.removeLast();
    }
    points.forEach((element) {
      canvas.drawCircle(element, _graphDetectWidth, _graphPaint);
    });
  }

  /// 绘制线段
  void _drawSegmentLine(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
    canvas.drawLine(points.first, points.last, _graphPaint);
  }

  /// 绘制射线
  void _drawRayLine(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
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
  void _drawStraightLine(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);
    canvas.drawLine(leftEdgePoint, rightEdgePoint, _graphPaint);
  }

  /// 绘制矩形
  void _drawRectangle(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
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
    var index = chartPainter.getIndex(touchPoint.dx / scaleX - mTranslateX);
    var price = _getMainPrice(touchPoint.dy);
    return DrawGraphRawValue(index, price);
  }

  /// 计算移动手势的点在k线图中对应的index和价格
  DrawGraphRawValue calculateMoveRawValue(Offset movePoint) {
    var index = chartPainter.getIndex(movePoint.dx / scaleX - mTranslateX);
    var dy = movePoint.dy;
    if (movePoint.dy < mMainRect.top) {
      dy = mMainRect.top;
    }
    if (movePoint.dy > mMainRect.bottom) {
      dy = mMainRect.bottom;
    }
    var price = _getMainPrice(dy);
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
        case DrawnGraphType.horizontalSegmentLine:
        case DrawnGraphType.verticalSegmentLine:
        case DrawnGraphType.rayLine:
        case DrawnGraphType.straightLine:
        case DrawnGraphType.horizontalStraightLine:
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
      case DrawnGraphType.horizontalSegmentLine:
      case DrawnGraphType.verticalSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.horizontalStraightLine:
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
  void moveActiveGraph(
    DrawGraphRawValue currentValue,
    DrawGraphRawValue nextValue,
    int? anchorIndex,
  ) {
    // 计算和上一个点的偏移
    var offset = Offset(nextValue.index - currentValue.index,
        nextValue.price - currentValue.price);
    // 没有选中锚点，或者激活的图形是一些特殊图形时，整体移动
    if (anchorIndex == null ||
        _activeDrawnGraph!.drawType == DrawnGraphType.horizontalSegmentLine ||
        _activeDrawnGraph!.drawType == DrawnGraphType.verticalSegmentLine ||
        _activeDrawnGraph!.drawType == DrawnGraphType.horizontalStraightLine) {
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
    var p1 = Offset(
        _translateIndexToX(value1.index), chartPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index), chartPainter.getMainY(value2.price));
    var valueRect = Rect.fromPoints(p1, p2).inflate(_graphDetectWidth);
    return valueRect.contains(touchPoint);
  }

  /// 点到线形的距离
  double _distanceToSingleLine(Offset touchPoint, DrawnGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(
        _translateIndexToX(value1.index), chartPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index), chartPainter.getMainY(value2.price));
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.horizontalSegmentLine:
      case DrawnGraphType.verticalSegmentLine:
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
      case DrawnGraphType.horizontalStraightLine:
        return DistanceUtil.distanceToSegment(
            touchPoint, leftEdgePoint, rightEdgePoint);
      default:
        return double.infinity;
    }
  }

  /// 点到各种形状的锚点的距离
  double _distanceToGraphAnchorPoint(
      Offset touchPoint, DrawGraphRawValue anchorValue) {
    var anchorPoint = Offset(_translateIndexToX(anchorValue.index),
        chartPainter.getMainY(anchorValue.price));
    return DistanceUtil.distanceToPoint(touchPoint, anchorPoint);
  }

  double _translateIndexToX(double index) {
    return chartPainter.translateXtoX(chartPainter.getX(index));
  }

  double _getMainPrice(double y) {
    return chartPainter.mMainRenderer.getPrice(y);
  }
}
