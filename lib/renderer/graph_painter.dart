// Author: Dean.Liu
// DateTime: 2022/09/06 15:50

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:k_chart/renderer/dash_path.dart';
import 'package:k_chart/renderer/index.dart';

import '../entity/draw_graph_entity.dart';
import '../entity/draw_graph_preset_styles.dart';
import '../utils/distance_util.dart';

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.stockPainter,
    required this.drawnGraphs,
    required this.timeInterval,
    required this.preset,
  }) : _activeDrawnGraph =
            drawnGraphs.firstWhereOrNull((graph) => graph.isActive);

  final ChartPainter stockPainter;
  final List<DrawnGraphEntity> drawnGraphs;

  /// 当前k线图的时间间隔。因为两个蜡烛之间的时间间隔可以不一致，无法作为绘图的基准，所以必须传入
  final int timeInterval;

  /// 预设的绘制图形样式
  final DrawGraphPresetStyles preset;

  Rect get mMainRect => stockPainter.mMainRect;

  double get mWidth => stockPainter.mWidth;

  double get scaleX => stockPainter.scaleX;

  double get mTranslateX => stockPainter.mTranslateX;

  DrawnGraphEntity? get activeDrawnGraph => _activeDrawnGraph;

  final _pointRadius = 5.0;

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
    _drawActiveAnchorPoints(canvas, _activeDrawnGraph);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  /// 创建描边的Paint
  Paint _createStokePaint(DrawnGraphStyle style) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeWidth = style.lineWidthFromPreset(preset)
      ..color = style.strokeColorFromPreset(preset);
  }

  /// 创建填充的Paint
  Paint _createFillPaint(DrawnGraphStyle style) {
    return Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = style.fillColorFromPreset(preset);
  }

  /// 创建锚点的Paint
  Paint _createAnchorPaint(DrawnGraphStyle style) {
    return Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = style.strokeColorFromPreset(preset);
  }

  /// 绘制线形图形的线条，例如线段
  void _drawLineGraphStroke(
      Canvas canvas, List<Offset> points, DrawnGraphStyle style) {
    final rawPath = Path()..addPolygon(points, false);
    final dashedLine = style.dashedLineFromPreset(preset);
    final path = dashedLine == null
        ? rawPath
        : dashPath(rawPath, dashArray: CircularIntervalList(dashedLine));
    canvas.drawPath(path, _createStokePaint(style));
  }

  /// 绘制面形图形的描边，例如矩形
  void _drawPlaneGraphStroke(
      Canvas canvas, List<Offset> points, DrawnGraphStyle style) {
    final rawPath = Path()..addPolygon(points, true);
    final dashedLine = style.dashedLineFromPreset(preset);
    final path = dashedLine == null
        ? rawPath
        : dashPath(rawPath, dashArray: CircularIntervalList(dashedLine));
    canvas.drawPath(path, _createStokePaint(style));
  }

  /// 绘制面性图形的填充，例如矩形
  void _drawPlaneGraphFill(
      Canvas canvas, List<Offset> points, DrawnGraphStyle style) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, _createFillPaint(style));
  }

  /// 绘制单个手绘图形
  void _drawSingleGraph(Canvas canvas, DrawnGraphEntity? graph) {
    if (graph == null) {
      return;
    }
    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.hSegmentLine:
      case DrawnGraphType.vSegmentLine:
        _drawSegmentLine(canvas, graph);
        break;
      case DrawnGraphType.rayLine:
        _drawRayLine(canvas, graph);
        break;
      case DrawnGraphType.straightLine:
      case DrawnGraphType.hStraightLine:
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
  }

  /// 获取图形的所有锚点坐标
  List<Offset> _getAnchorPoints(DrawnGraphEntity graph) {
    return graph.values.map((value) {
      return _getAnchorPoint(value);
    }).toList();
  }

  /// 根据graphValue计算锚点坐标
  Offset _getAnchorPoint(DrawGraphAnchor graphValue) {
    double dx = _translateIndexToX(graphValue.index!);
    double dy = stockPainter.getMainY(graphValue.price);
    return Offset(dx, dy);
  }

  /// 绘制激活的图形的锚点
  void _drawActiveAnchorPoints(Canvas canvas, DrawnGraphEntity? graph) {
    if (graph == null || !graph.isActive) return;
    final points = _getAnchorPoints(graph);
    // 水平直线只显示一个锚点
    if (graph.drawType == DrawnGraphType.hStraightLine) {
      points.removeLast();
    }
    points.forEach((element) {
      canvas.drawCircle(element, _pointRadius, _createAnchorPaint(graph.style));
    });
  }

  /// 图形是否可以绘制
  bool _isGraphValid(DrawnGraphEntity graph, int minCount) {
    if (graph.values.length < minCount ||
        graph.values.any((e) => e.index == null)) {
      return false;
    }
    return true;
  }

  /// 绘制线段
  void _drawSegmentLine(Canvas canvas, DrawnGraphEntity graph) {
    if (!_isGraphValid(graph, 2)) return;
    final points = _getAnchorPoints(graph);
    _drawLineGraphStroke(canvas, points, graph.style);
  }

  /// 绘制射线
  void _drawRayLine(Canvas canvas, DrawnGraphEntity graph) {
    if (!_isGraphValid(graph, 2)) return;
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
    _drawLineGraphStroke(canvas, [p1, endPoint], graph.style);
  }

  /// 绘制直线
  void _drawStraightLine(Canvas canvas, DrawnGraphEntity graph) {
    if (!_isGraphValid(graph, 2)) return;
    final points = _getAnchorPoints(graph);
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);
    _drawLineGraphStroke(canvas, [leftEdgePoint, rightEdgePoint], graph.style);
  }

  /// 绘制矩形
  void _drawRectangle(Canvas canvas, DrawnGraphEntity graph) {
    if (!_isGraphValid(graph, 2)) return;
    final points = _getAnchorPoints(graph);
    final p1 = points[0];
    final p2 = points[1];
    final rectPoints = [p1, Offset(p2.dx, p1.dy), p2, Offset(p1.dx, p2.dy)];
    _drawPlaneGraphStroke(canvas, rectPoints, graph.style);
    _drawPlaneGraphFill(canvas, rectPoints, graph.style);
  }

  /// 绘制平行线
  void _drawParallelLine(Canvas canvas, DrawnGraphEntity graph) {
    final points = _getParallelLinePoints(graph);
    if (!_isGraphValid(graph, 2)) return;
    final firstPoint = points[0];
    final secondPoint = points[1];
    // 绘制前两个点指示的直线
    _drawLineGraphStroke(canvas, [firstPoint, secondPoint], graph.style);
    if (points.length != 4) return;
    final thirdPoint = points[2];
    final fourthPoint = points[3];
    // 第三个点指示的直线
    _drawLineGraphStroke(canvas, [thirdPoint, fourthPoint], graph.style);
    _drawPlaneGraphFill(canvas, points, graph.style);
  }

  /// 绘制几浪
  void _drawWave(Canvas canvas, DrawnGraphEntity graph) {
    final points = _getAnchorPoints(graph);
    if (!_isGraphValid(graph, 2)) return;
    _drawLineGraphStroke(canvas, points, graph.style);
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
    if (!_isGraphValid(graph, 2)) return [];
    final firstValue = graph.values[0];
    final secondValue = graph.values[1];
    final firstPoint = _getAnchorPoint(firstValue);
    final secondPoint = _getAnchorPoint(secondValue);
    if (graph.values.length != 3) {
      return [firstPoint, secondPoint];
    }
    final thirdValue = graph.values[2];
    final diffIndex = (firstValue.index! - secondValue.index!) == 0
        ? 0.1
        : firstValue.index! - secondValue.index!;
    // 价格差/index差
    final tan = (firstValue.price - secondValue.price) / diffIndex;
    // lastValue的index，在第一条直线上的价格
    final priceInBaseLine =
        firstValue.price + (thirdValue.index! - firstValue.index!) * tan;
    final diffPrice = thirdValue.price - priceInBaseLine;
    final thirdPoint = _getAnchorPoint(DrawGraphAnchor(
      index: firstValue.index,
      price: firstValue.price + diffPrice,
    ));
    final fourthPoint = _getAnchorPoint(DrawGraphAnchor(
      index: secondValue.index,
      price: secondValue.price + diffPrice,
    ));
    // 1-2-4-3-1 组成封闭图形
    return [firstPoint, secondPoint, fourthPoint, thirdPoint];
  }

  /// 计算点击手势的点在k线图中对应的index和价格
  DrawGraphAnchor? calculateTouchRawValue(Offset touchPoint) {
    var index = stockPainter.getIndex(touchPoint.dx / scaleX - mTranslateX);
    var price = _getMainPrice(touchPoint.dy);
    return DrawGraphAnchor(index: index, price: price);
  }

  /// 全部锚点图形的最后一个的value
  DrawGraphAnchor getLastAnchorGraphValue(
    DrawnGraphType drawType,
    List<DrawGraphAnchor> values,
    DrawGraphAnchor lastValue,
  ) {
    if (drawType == DrawnGraphType.hSegmentLine) {
      lastValue.price = values.first.price;
    }
    if (drawType == DrawnGraphType.vSegmentLine) {
      lastValue.index = values.first.index;
    }
    if (drawType == DrawnGraphType.parallelLine) {
      final firstValue = values[0];
      final secondValue = values[1];
      final minIndex = min(firstValue.index!, secondValue.index!);
      final maxIndex = max(firstValue.index!, secondValue.index!);
      if (lastValue.index! < minIndex) {
        lastValue.index = minIndex;
      }
      if (lastValue.index! > maxIndex) {
        lastValue.index = maxIndex;
      }
    }
    return lastValue;
  }

  /// 计算指定图形的时间
  void calculateDrawnGraphTime(DrawnGraphEntity? graph) {
    graph?.values.forEach((value) {
      final indexTime = calculateIndexTime(value.index!);
      value.time = indexTime;
    });
  }

  int? calculateIndexTime(double index) {
    final intIndex = index.floor();
    final dataCount = stockPainter.datas!.length - 1;
    int baseIndex;
    int interval;
    // 如果点击的位置超出k线区域，以最后一根k线的时间作为基准
    if (intIndex >= dataCount) {
      baseIndex = dataCount;
      interval = timeInterval;
    } else {
      baseIndex = intIndex;
      final nextIndex = baseIndex + 1;
      final baseTime = stockPainter.datas![baseIndex].time;
      final nextTime = stockPainter.datas![nextIndex].time;
      if (baseTime == null || nextTime == null) {
        interval = timeInterval;
      } else {
        interval = nextTime - baseTime;
      }
    }

    // 点击位置对应x轴的时间戳
    int? pointTime;
    final baseTime = stockPainter.datas![baseIndex].time;
    if (baseTime != null) {
      pointTime = ((index - baseIndex) * interval + baseTime).toInt();
    }
    return pointTime;
  }

  /// 计算移动手势的点在k线图中对应的index和价格
  DrawGraphAnchor calculateMoveRawValue(Offset movePoint) {
    var index = stockPainter.getIndex(movePoint.dx / scaleX - mTranslateX);
    var dy = movePoint.dy;
    if (movePoint.dy < mMainRect.top) {
      dy = mMainRect.top;
    }
    if (movePoint.dy > mMainRect.bottom) {
      dy = mMainRect.bottom;
    }
    var price = _getMainPrice(dy);
    return DrawGraphAnchor(index: index, price: price);
  }

  /// 根据touch点，查找离它最近的图形
  void detectDrawnGraphs(Offset touchPoint) {
    if (drawnGraphs.isEmpty) {
      return;
    }
    drawnGraphs.forEach((graph) => graph.isActive = false);
    _activeDrawnGraph = null;
    if (_detectLineTypeGraph(touchPoint)) return;
    if (_detectPlaneTypeGraph(touchPoint)) return;
  }

  /// 点击的时候，激活图形
  bool _activeGraph(DrawnGraphEntity graph) {
    graph.isActive = true;
    _activeDrawnGraph = graph;
    return true;
  }

  /// 激活线状图形，返回值表示是否激活成功
  bool _detectLineTypeGraph(Offset touchPoint) {
    final detectFunctions = [
      _detectWaveGraph,
      _detectNormalLineGraph,
    ];
    for (var graph in drawnGraphs.reversed) {
      // 任何一个detect返回了true
      final detectSuccess = detectFunctions.any((function) {
        return function(graph, touchPoint);
      });
      if (detectSuccess) {
        return true;
      }
    }
    return false;
  }

  /// 激活面状图形，返回值表示是否激活成功
  bool _detectPlaneTypeGraph(Offset touchPoint) {
    final detectFunctions = [
      _detectParallelLineGraph,
      _detectReactGraph,
    ];
    for (var graph in drawnGraphs.reversed) {
      // 任何一个detect返回了true
      final detectSuccess = detectFunctions.any((function) {
        return function(graph, touchPoint);
      });
      if (detectSuccess) {
        return true;
      }
    }
    return false;
  }

  /// 返回是否成功激活平行线
  bool _detectParallelLineGraph(DrawnGraphEntity graph, Offset touchPoint) {
    if (graph.drawType == DrawnGraphType.parallelLine &&
        _isPointInParallelLinePlane(touchPoint, graph)) {
      return _activeGraph(graph);
    }
    return false;
  }

  /// 返回是否成功激活矩形
  bool _detectReactGraph(DrawnGraphEntity graph, Offset touchPoint) {
    if (graph.drawType == DrawnGraphType.rectangle &&
        _isPointInRectangle(touchPoint, graph)) {
      return _activeGraph(graph);
    }
    return false;
  }

  /// 返回是否成功激活几浪
  bool _detectWaveGraph(DrawnGraphEntity graph, Offset touchPoint) {
    if ((graph.drawType == DrawnGraphType.threeWave ||
            graph.drawType == DrawnGraphType.fiveWave) &&
        _isPointInWave(touchPoint, graph)) {
      return _activeGraph(graph);
    }
    return false;
  }

  /// 返回是否成功普通线形
  bool _detectNormalLineGraph(DrawnGraphEntity graph, Offset touchPoint) {
    final lineTypes = [
      DrawnGraphType.segmentLine,
      DrawnGraphType.hSegmentLine,
      DrawnGraphType.vSegmentLine,
      DrawnGraphType.rayLine,
      DrawnGraphType.straightLine,
      DrawnGraphType.hStraightLine,
    ];
    if (lineTypes.contains(graph.drawType)) {
      var distance = _distanceToSingleLine(touchPoint, graph);
      if (distance < _graphDetectWidth) {
        return _activeGraph(graph);
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
    if (_activeDrawnGraph?.drawFinished != true) {
      return false;
    }
    switch (_activeDrawnGraph!.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.hSegmentLine:
      case DrawnGraphType.vSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.hStraightLine:
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
    DrawGraphAnchor currentValue,
    DrawGraphAnchor nextValue,
    int? anchorIndex,
  ) {
    // 计算和上一个点的偏移
    var offset = Offset(nextValue.index! - currentValue.index!,
        nextValue.price - currentValue.price);
    if (anchorIndex == null) {
      _activeDrawnGraph?.values.forEach((value) {
        value.index = value.index! + offset.dx;
        value.price += offset.dy;
      });
    } else {
      if (_activeDrawnGraph!.drawType == DrawnGraphType.hSegmentLine ||
          _activeDrawnGraph!.drawType == DrawnGraphType.hStraightLine) {
        _activeDrawnGraph!.values[anchorIndex].index =
            _activeDrawnGraph!.values[anchorIndex].index! + offset.dx;
        _activeDrawnGraph!.values.forEach((graph) {
          graph.price += offset.dy;
        });
      } else if (_activeDrawnGraph!.drawType == DrawnGraphType.vSegmentLine) {
        _activeDrawnGraph!.values[anchorIndex].price += offset.dy;
        _activeDrawnGraph!.values.forEach((graph) {
          graph.index = graph.index! + offset.dx;
        });
      } else {
        _activeDrawnGraph!.values[anchorIndex].index =
            _activeDrawnGraph!.values[anchorIndex].index! + offset.dx;
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
    final minIndex = min(firstValue.index!, secondValue.index!);
    final maxIndex = max(firstValue.index!, secondValue.index!);
    if (thirdValue.index! < minIndex) {
      thirdValue.index = minIndex;
    }
    if (thirdValue.index! > maxIndex) {
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
        _translateIndexToX(value1.index!), stockPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index!), stockPainter.getMainY(value2.price));
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
        _translateIndexToX(value1.index!), stockPainter.getMainY(value1.price));
    var p2 = Offset(
        _translateIndexToX(value2.index!), stockPainter.getMainY(value2.price));
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    switch (graph.drawType) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.hSegmentLine:
      case DrawnGraphType.vSegmentLine:
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
      case DrawnGraphType.hStraightLine:
        return DistanceUtil.distanceToSegment(
            touchPoint, leftEdgePoint, rightEdgePoint);
      default:
        return double.infinity;
    }
  }

  /// 点到各种形状的锚点的距离
  double _distanceToGraphAnchorPoint(
      Offset touchPoint, DrawGraphAnchor anchorValue) {
    var anchorPoint = Offset(_translateIndexToX(anchorValue.index!),
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
