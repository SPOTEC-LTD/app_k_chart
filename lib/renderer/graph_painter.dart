// Author: Dean.Liu
// DateTime: 2022/09/06 15:50

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:k_chart/renderer/index.dart';

import '../entity/draw_graph_entity.dart';
import '../utils/distance_util.dart';

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.stockPainter,
    required this.drawnGraphs,
  }) : _activeDrawnGraph =
            drawnGraphs.firstWhereOrNull((graph) => graph.isActive);

  final ChartPainter stockPainter;
  final List<DrawnGraphEntity> drawnGraphs;

  Rect get mMainRect => stockPainter.mMainRect;

  double get mWidth => stockPainter.mWidth;

  double get scaleX => stockPainter.scaleX;

  double get mTranslateX => stockPainter.mTranslateX;

  DrawnGraphEntity? get activeDrawnGraph => _activeDrawnGraph;

  final _strokePaint = Paint()
    ..strokeWidth = 1.0
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..color = Colors.red;

  final _fillPaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.red.withOpacity(0.2);

  final _anchorPaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.orange;

  final _pointRadius = 7.5;

  /// 判断激活哪个图形时，添加的外边距
  final _graphDetectWidth = 10.0;

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
      case DrawnGraphType.parallelLine:
        _drawParallelLine(canvas, graph);
        break;
      case DrawnGraphType.threeWave:
      case DrawnGraphType.fiveWave:
        _drawWave(canvas, graph);
        break;
      default:
    }
    _drawActiveAnchorPoints(canvas, graph);
  }

  /// 获取图形的所有锚点坐标
  List<Offset> _getAnchorPoints(DrawnGraphEntity graph) {
    return graph.values.map((value) {
      return _getAnchorPoint(value);
    }).toList();
  }

  /// 根据graphValue计算锚点坐标
  Offset _getAnchorPoint(DrawGraphRawValue graphValue) {
    double dx = _translateIndexToX(graphValue.index);
    double dy = stockPainter.getMainY(graphValue.price);
    return Offset(dx, dy);
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
      canvas.drawCircle(element, _pointRadius, _anchorPaint);
    });
  }

  /// 绘制线段
  void _drawSegmentLine(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
    canvas.drawLine(points.first, points.last, _strokePaint);
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
    canvas.drawLine(p1, endPoint, _strokePaint);
  }

  /// 绘制直线
  void _drawStraightLine(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);
    canvas.drawLine(leftEdgePoint, rightEdgePoint, _strokePaint);
  }

  /// 绘制矩形
  void _drawRectangle(Canvas canvas, DrawnGraphEntity graph) {
    if (graph.values.length != 2) return;
    final points = _getAnchorPoints(graph);
    var rect = Rect.fromPoints(points.first, points.last);
    canvas.drawRect(rect, _strokePaint);
    canvas.drawRect(rect, _fillPaint);
  }

  /// 绘制平行线
  void _drawParallelLine(Canvas canvas, DrawnGraphEntity graph) {
    final points = _getParallelLinePoints(graph);
    if (points.length < 2) return;
    final firstPoint = points[0];
    final secondPoint = points[1];
    // 绘制前两个点指示的直线
    canvas.drawLine(firstPoint, secondPoint, _strokePaint);
    if (points.length != 4) return;
    final thirdPoint = points[2];
    final fourthPoint = points[3];
    // 第三个点指示的直线
    canvas.drawLine(thirdPoint, fourthPoint, _strokePaint);

    final path = Path();
    path.addPolygon(points, true);
    canvas.drawPath(path, _fillPaint);
  }

  /// 绘制几浪
  void _drawWave(Canvas canvas, DrawnGraphEntity graph) {
    final points = _getAnchorPoints(graph);
    if (points.length < 2) return;
    final path = Path();
    path.addPolygon(points, false);
    canvas.drawPath(path, _strokePaint);
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

  // 运行到这儿一定会有两个点
  List<Offset> _getParallelLinePoints(DrawnGraphEntity graph) {
    if (graph.values.length < 2) return [];
    final firstValue = graph.values[0];
    final secondValue = graph.values[1];
    final firstPoint = _getAnchorPoint(firstValue);
    final secondPoint = _getAnchorPoint(secondValue);
    if (graph.values.length != 3) {
      return [firstPoint, secondPoint];
    }
    final thirdValue = graph.values[2];
    final diffIndex = (firstValue.index - secondValue.index) == 0
        ? 0.1
        : firstValue.index - secondValue.index;
    // 价格差/index差
    final tan = (firstValue.price - secondValue.price) / diffIndex;
    // lastValue的index，在第一条直线上的价格
    final priceInBaseLine =
        firstValue.price + (thirdValue.index - firstValue.index) * tan;
    final diffPrice = thirdValue.price - priceInBaseLine;
    final thirdPoint = _getAnchorPoint(
        DrawGraphRawValue(firstValue.index, firstValue.price + diffPrice));
    final fourthPoint = _getAnchorPoint(
        DrawGraphRawValue(secondValue.index, secondValue.price + diffPrice));
    // 1-2-4-3-1 组成封闭图形
    return [firstPoint, secondPoint, fourthPoint, thirdPoint];
  }

  /// 计算点击手势的点在k线图中对应的index和价格
  DrawGraphRawValue? calculateTouchRawValue(Offset touchPoint) {
    var index = stockPainter.getIndex(touchPoint.dx / scaleX - mTranslateX);
    var price = _getMainPrice(touchPoint.dy);
    return DrawGraphRawValue(index, price);
  }

  /// 计算移动手势的点在k线图中对应的index和价格
  DrawGraphRawValue calculateMoveRawValue(Offset movePoint) {
    var index = stockPainter.getIndex(movePoint.dx / scaleX - mTranslateX);
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
    _activeDrawnGraph = null;
    if (_detectSingleLine(touchPoint)) {
      return;
    }
    if (_detectWave(touchPoint)) {
      return;
    }
    if (_detectRectangle(touchPoint)) {
      return;
    }
    if (_detectParallelLinePlane(touchPoint)) {
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
    for (var i = singleLineGraphs.length - 1; i >= 0; i--) {
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
    for (var graph in drawnGraphs.reversed) {
      if (graph.drawType == DrawnGraphType.rectangle &&
          _isPointInRectangle(touchPoint, graph)) {
        graph.isActive = true;
        _activeDrawnGraph = graph;
        return true;
      }
    }
    return false;
  }

  bool _detectParallelLinePlane(Offset touchPoint) {
    for (var graph in drawnGraphs.reversed) {
      if (graph.drawType == DrawnGraphType.parallelLine &&
          _isPointInParallelLinePlane(touchPoint, graph)) {
        graph.isActive = true;
        _activeDrawnGraph = graph;
        return true;
      }
    }
    return false;
  }

  bool _detectWave(Offset touchPoint) {
    for (var graph in drawnGraphs.reversed) {
      if (_isPointInWave(touchPoint, graph)) {
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
    // 没有激活的图形，或者激活的图形没有绘制完成
    if (_activeDrawnGraph == null ||
        _activeDrawnGraph!.drawType.anchorCount !=
            _activeDrawnGraph!.values.length) {
      return false;
    }
    switch (_activeDrawnGraph!.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.horizontalSegmentLine:
      case DrawnGraphType.verticalSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.horizontalStraightLine:
        return _isPointInSegment(touchPoint, _activeDrawnGraph!);
      case DrawnGraphType.rectangle:
        return _isPointInRectangle(touchPoint, _activeDrawnGraph!);
      case DrawnGraphType.parallelLine:
        return _isPointInParallelLinePlane(touchPoint, _activeDrawnGraph!);
      case DrawnGraphType.threeWave:
      case DrawnGraphType.fiveWave:
        return _isPointInWave(touchPoint, _activeDrawnGraph!);
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
    if (anchorIndex == null) {
      _activeDrawnGraph?.values.forEach((value) {
        value.index += offset.dx;
        value.price += offset.dy;
      });
    } else {
      if (_activeDrawnGraph!.drawType == DrawnGraphType.horizontalSegmentLine ||
          _activeDrawnGraph!.drawType ==
              DrawnGraphType.horizontalStraightLine) {
        _activeDrawnGraph!.values[anchorIndex].index += offset.dx;
      } else if (_activeDrawnGraph!.drawType ==
          DrawnGraphType.verticalSegmentLine) {
        _activeDrawnGraph!.values[anchorIndex].price += offset.dy;
      } else {
        _activeDrawnGraph!.values[anchorIndex].index += offset.dx;
        _activeDrawnGraph!.values[anchorIndex].price += offset.dy;
      }
      if (_activeDrawnGraph!.drawType == DrawnGraphType.parallelLine) {
        _adaptiveParallelLineGraphValue(anchorIndex);
      }
    }
  }

  /// 移动时调整锚点位置
  void _adaptiveParallelLineGraphValue(int anchorIndex) {
    final firstValue = _activeDrawnGraph!.values[0];
    final secondValue = _activeDrawnGraph!.values[1];
    final thirdValue = _activeDrawnGraph!.values[2];
    final minIndex = min(firstValue.index, secondValue.index);
    final maxIndex = max(firstValue.index, secondValue.index);
    if (thirdValue.index < minIndex) {
      thirdValue.index = minIndex;
    }
    if (thirdValue.index > maxIndex) {
      thirdValue.index = maxIndex;
    }
  }

  /// 点是否在线段中（靠近）
  bool _isPointInSegment(Offset touchPoint, DrawnGraphEntity graph) {
    var distance = _distanceToSingleLine(touchPoint, _activeDrawnGraph!);
    return distance < _graphDetectWidth;
  }

  /// 点是否在矩形中
  bool _isPointInRectangle(Offset touchPoint, DrawnGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(
        _translateIndexToX(value1.index), stockPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index), stockPainter.getMainY(value2.price));
    var valueRect = Rect.fromPoints(p1, p2).inflate(_graphDetectWidth);
    return valueRect.contains(touchPoint);
  }

  /// 点是否在平行线平面中
  bool _isPointInParallelLinePlane(Offset touchPoint, DrawnGraphEntity graph) {
    final points = _getParallelLinePoints(graph);
    final firstPoint = points[0];
    final secondPoint = points[1];
    final thirdPoint = points[2];
    final fourthPoint = points[3];
    final path = Path();
    path.addPolygon(points, true);
    final pathContain = path.contains(touchPoint);
    final detectLine1 = DistanceUtil.distanceToSegment(
          touchPoint,
          firstPoint,
          secondPoint,
        ) <
        _graphDetectWidth;
    final detectLine2 = DistanceUtil.distanceToSegment(
          touchPoint,
          thirdPoint,
          fourthPoint,
        ) <
        _graphDetectWidth;
    return pathContain || detectLine1 || detectLine2;
  }

  /// 点是否在几浪的折线图中
  bool _isPointInWave(Offset touchPoint, DrawnGraphEntity graph) {
    if (!(graph.drawType == DrawnGraphType.threeWave ||
        graph.drawType == DrawnGraphType.fiveWave)) {
      return false;
    }
    final points = _getAnchorPoints(graph);
    for (var index = 0; index < points.length; index++) {
      if (index == 0) continue;
      final prePoint = points[index - 1];
      final curPoint = points[index];
      final dis =
          DistanceUtil.distanceToSegment(touchPoint, prePoint, curPoint);
      if (dis < _graphDetectWidth) {
        return true;
      }
    }
    return false;
  }

  /// 点到线形的距离
  double _distanceToSingleLine(Offset touchPoint, DrawnGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(
        _translateIndexToX(value1.index), stockPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index), stockPainter.getMainY(value2.price));
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
        stockPainter.getMainY(anchorValue.price));
    return DistanceUtil.distanceToPoint(touchPoint, anchorPoint);
  }

  double _translateIndexToX(double index) {
    return stockPainter.translateXtoX(stockPainter.getX(index));
  }

  double _getMainPrice(double y) {
    return stockPainter.mMainRenderer.getPrice(y);
  }
}
