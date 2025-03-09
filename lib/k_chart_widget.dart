import 'dart:async';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:k_chart/indicator_setting.dart';
import 'package:k_chart/renderer/graph_painter.dart';

import 'entity/draw_graph_entity.dart';
import 'entity/draw_graph_preset_styles.dart';

enum MainState { NONE, MA, EMA, BOLL }

enum SecondaryState { NONE, VOLUME, MACD, KDJ, RSI, WR, CCI }

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  final List<SecondaryState> secondaryStates;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool isTapShowInfoDialog; //是否开启单击显示详情数据
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material风格的信息弹窗
  final ChartTranslations translations;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final IndicatorSetting indicatorSetting;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final bool isTrendLine;

  final KChartController? chartController;

  /// 是否启用绘图模式
  final bool enableDraw;

  /// 绘制图形的类型
  final DrawnGraphType? drawType;

  /// 预设的绘制图形样式
  final DrawGraphPresetStyles? presetDrawStyles;

  /// 绘制图形的样式
  final DrawnGraphStyle? drawStyle;

  /// 是否显示绘制的图形
  final bool showDrawnGraphs;

  /// 当前k线图的时间间隔。因为两个蜡烛之间的时间间隔可以不一致，无法作为绘图的基准，所以必须传入
  final int timeInterval;

  /// 绘制当前图形，返回值表示是否绘制完成
  final ValueSetter<bool>? drawGraphProgress;

  /// 是否激活了某个图形
  final ValueSetter<bool>? anyGraphDetected;

  /// 当前图形移动完成
  final VoidCallback? moveFinished;

  /// 画图点击事件超出主图范围
  final VoidCallback? outMainTap;

  final ui.Image? logoImage;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    required this.timeInterval,
    required this.isTrendLine,
    this.mainState = MainState.MA,
    this.secondaryStates = const [SecondaryState.VOLUME],
    this.onSecondaryTap,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.translations = kChartTranslations,
    this.onLoadMore,
    this.fixedLength = 2,
    this.indicatorSetting = const IndicatorSetting(),
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
    this.chartController,
    this.enableDraw = false,
    this.drawType,
    this.showDrawnGraphs = true,
    this.presetDrawStyles,
    this.drawStyle,
    this.outMainTap,
    this.drawGraphProgress,
    this.anyGraphDetected,
    this.moveFinished,
    this.logoImage,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mHeight = 0, mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;

  //For TrendLine
  List<TrendLine> lines = [];
  double? changeinXposition;
  double? changeinYposition;
  double mSelectY = 0.0;
  bool waitingForOtherPairofCords = false;
  bool enableCordRecord = false;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false, isOnTap = false;

  // 是否正在完成缩放。缩放完成时，手指移动会引起drag事件，设置等待0.1s再完成缩放
  bool _isFinishingScale = false;

  /// 长按手势当前点的value值
  DrawGraphAnchor? _currentPressValue;

  /// 选中锚点在DrawGraphEntity的value数组中的索引
  int? _pressAnchorIndex;

  /// 是否可以绘制手画的图形
  bool get _enableDraw => widget.enableDraw;

  final _defaultChartController = KChartController();

  KChartController get _chartController =>
      widget.chartController ?? _defaultChartController;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
    _chartController.hideInfoDialogFunction = _hideInfoDialog;
    _chartController.resetMScrollXFunction = _resetMScrollX;
    _chartController.addListener(_onChartController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    _chartController.removeListener(_onChartController);
    _defaultChartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final secondaryStates = [...widget.secondaryStates];
    secondaryStates.removeWhere((e) => e == SecondaryState.NONE);
    final _stockPainter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      lines: lines,
      //For TrendLine
      isTrendLine: widget.isTrendLine,
      //For TrendLine
      selectY: mSelectY,
      //For TrendLine
      datas: widget.datas,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainState: widget.mainState,
      secondaryStates: secondaryStates,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      fixedLength: widget.fixedLength,
      indicatorSetting: widget.indicatorSetting,
      verticalTextAlignment: widget.verticalTextAlignment,
      dateTimeFormat: gerRealDateTimeFormat(),
      inheritedTextStyle: DefaultTextStyle.of(context).style,
      logoImage: widget.logoImage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        return GestureDetector(
          onTapUp: (details) {
            if (!widget.isTrendLine &&
                widget.onSecondaryTap != null &&
                _stockPainter.isInSecondaryRect(details.localPosition)) {
              widget.onSecondaryTap!();
            }

            if (!widget.isTrendLine &&
                _stockPainter.isInMainRect(details.localPosition)) {
              isOnTap = true;
              if (mSelectX != details.localPosition.dx &&
                  widget.isTapShowInfoDialog) {
                mSelectX = details.localPosition.dx;
                mSelectY = details.localPosition.dy;
                notifyChanged();
              }
            }
            if (widget.isTrendLine && !isLongPress && enableCordRecord) {
              enableCordRecord = false;
              Offset p1 = Offset(getTrendLineX(), mSelectY);
              if (!waitingForOtherPairofCords)
                lines.add(TrendLine(
                    p1, Offset(-1, -1), trendLineMax!, trendLineScale!));

              if (waitingForOtherPairofCords) {
                var a = lines.last;
                lines.removeLast();
                lines.add(TrendLine(a.p1, p1, trendLineMax!, trendLineScale!));
                waitingForOtherPairofCords = false;
              } else {
                waitingForOtherPairofCords = true;
              }
              notifyChanged();
            }
          },
          onScaleStart: (details) {
            if (_isFinishingScale) return;
            isOnTap = false;
            _stopAnimation();
            _onDragChanged(true);
            if (details.pointerCount == 1) {
              // drag
              isDrag = true;
              isScale = false;
            } else {
              // scale
              isDrag = false;
              isScale = true;
            }
          },
          onScaleUpdate: (details) {
            if (isLongPress || _isFinishingScale) return;
            if (details.pointerCount == 1) {
              mScrollX = ((details.focalPointDelta.dx) / mScaleX + mScrollX)
                  .clamp(0.0, ChartPainter.maxScrollX)
                  .toDouble();
            } else {
              mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
            }
            notifyChanged();
          },
          onScaleEnd: (details) {
            if (_isFinishingScale) return;
            if (isDrag) {
              isDrag = false;
              var velocity = details.velocity.pixelsPerSecond.dx;
              _onFling(velocity);
            }
            if (isScale) {
              isScale = false;
              _lastScale = mScaleX;
              _isFinishingScale = true;
              Future.delayed(Duration(milliseconds: 100), () {
                _isFinishingScale = false;
              });
            }
          },
          onLongPressStart: (details) {
            isOnTap = false;
            isLongPress = true;
            if ((mSelectX != details.localPosition.dx ||
                    mSelectY != details.localPosition.dy) &&
                !widget.isTrendLine) {
              mSelectX = details.localPosition.dx;
              mSelectY = details.localPosition.dy;
              notifyChanged();
            }
            //For TrendLine
            if (widget.isTrendLine && changeinXposition == null) {
              mSelectX = changeinXposition = details.localPosition.dx;
              mSelectY = changeinYposition = details.localPosition.dy;
              notifyChanged();
            }
            //For TrendLine
            if (widget.isTrendLine && changeinXposition != null) {
              changeinXposition = details.localPosition.dx;
              changeinYposition = details.localPosition.dy;
              notifyChanged();
            }
          },
          onLongPressMoveUpdate: (details) {
            if ((mSelectX != details.localPosition.dx ||
                    mSelectY != details.localPosition.dy) &&
                !widget.isTrendLine) {
              mSelectX = details.localPosition.dx;
              mSelectY = details.localPosition.dy;
              notifyChanged();
            }
            if (widget.isTrendLine) {
              mSelectX =
                  mSelectX + (details.localPosition.dx - changeinXposition!);
              changeinXposition = details.localPosition.dx;
              mSelectY =
                  mSelectY + (details.localPosition.dy - changeinYposition!);
              changeinYposition = details.localPosition.dy;
              notifyChanged();
            }
          },
          onLongPressEnd: (details) {
            isLongPress = false;
            enableCordRecord = true;
            mInfoWindowStream?.sink.add(null);
            notifyChanged();
          },
          child: Stack(
            children: <Widget>[
              CustomPaint(
                size: Size(double.infinity, double.infinity),
                painter: _stockPainter,
              ),
              if ((widget.datas != null && widget.datas!.isNotEmpty) &&
                  widget.showDrawnGraphs &&
                  widget.presetDrawStyles != null &&
                  (_chartController.drawnGraphs.isNotEmpty ||
                      (widget.drawType != null && widget.drawStyle != null)))
                _buildDrawGraphView(_stockPainter),
              if (widget.showInfoDialog) _buildInfoDialog()
            ],
          ),
        );
      },
    );
  }

  void _hideInfoDialog() {
    isLongPress = false;
    isOnTap = false;
    mInfoWindowStream?.sink.add(null);
    notifyChanged();
  }

  void _resetMScrollX() {
    mScrollX = 0;
    notifyChanged();
  }

  void _onChartController() {
    notifyChanged();
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if ((!isLongPress && !isOnTap) ||
              widget.isLine == true ||
              !snapshot.hasData ||
              snapshot.data?.kLineEntity == null) return Container();
          KLineEntity entity = snapshot.data!.kLineEntity;
          double upDown = entity.change ?? entity.close - entity.open;
          double upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
          final double? entityAmount = entity.amount;
          infos = [
            getDate(entity.time),
            entity.open.toStringAsFixed(widget.fixedLength),
            entity.high.toStringAsFixed(widget.fixedLength),
            entity.low.toStringAsFixed(widget.fixedLength),
            entity.close.toStringAsFixed(widget.fixedLength),
            "${upDown > 0 ? "+" : ""}${upDown.toStringAsFixed(widget.fixedLength)}",
            "${upDownPercent > 0 ? "+" : ''}${upDownPercent.toStringAsFixed(2)}%",
            NumberUtil.format(entity.vol),
            if (entityAmount != null) entityAmount.toInt().toString(),
          ];
          final dialogPadding = widget.chartStyle.selectPadding ?? 5.0;
          final dialogWidth = widget.chartStyle.selectWidth ?? mWidth / 3;
          return Container(
            margin: EdgeInsets.only(
                left: snapshot.data!.isLeft
                    ? dialogPadding
                    : mWidth - dialogWidth - dialogPadding,
                top: 25),
            width: dialogWidth,
            decoration: BoxDecoration(
              color: widget.chartColors.selectFillColor,
              border: Border.all(
                color: widget.chartColors.selectBorderColor,
                width: widget.chartStyle.selectBorderWidth,
              ),
              borderRadius: BorderRadius.circular(
                widget.chartStyle.selectBorderRadius,
              ),
            ),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: dialogPadding,
                vertical: dialogPadding - 2.5, // item上下各有2.5的间隔
              ),
              itemCount: infos.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                return _buildItem(
                  infos[index],
                  widget.translations.byIndex(index),
                );
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith('+'))
      color = widget.chartColors.infoWindowUpColor;
    else if (info.startsWith('-')) color = widget.chartColors.infoWindowDnColor;
    final infoWidget = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            '$infoName',
            style: TextStyle(
              color: widget.chartColors.infoWindowTitleColor,
              fontSize: 9,
            ),
          ),
        ),
        Text(
          info,
          style: TextStyle(
            color: color,
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5),
      child: widget.materialInfoDialog
          ? Material(color: Colors.transparent, child: infoWidget)
          : infoWidget,
    );
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      gerRealDateTimeFormat());

  /// 根据返回数据的时间间隔计算正确的时间格式
  List<String> gerRealDateTimeFormat() {
    if (widget.chartStyle.dateTimeFormat != null) {
      return widget.chartStyle.dateTimeFormat!;
    }

    if ((widget.datas?.length ?? 0) < 2) {
      return [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn];
    }
    int time = widget.timeInterval;
    time ~/= 1000;
    //月线
    if (time >= 24 * 60 * 60 * 28)
      return [yy, '-', mm];
    //日线等
    else if (time >= 24 * 60 * 60)
      return [yy, '-', mm, '-', dd];
    //小时线等
    else
      return [mm, '-', dd, ' ', HH, ':', nn];
  }

  Widget _buildDrawGraphView(ChartPainter stockPainter) {
    final _graphPainter = GraphPainter(
      stockPainter: stockPainter,
      drawnGraphs: _chartController.drawnGraphs,
      timeInterval: widget.timeInterval,
      preset: widget.presetDrawStyles!,
    );
    final paint = CustomPaint(
      size: Size(double.infinity, double.infinity),
      painter: _graphPainter,
    );
    if (_enableDraw) {
      // 激活的图形是否已完成绘制，已完成才可以拖动，否则会和stockPainter的手势冲突
      return GestureDetector(
        onTapUp: (details) {
          if (stockPainter.isInMainRect(details.localPosition)) {
            _mainRectTappedWithEnableDraw(_graphPainter, details.localPosition);
          }
        },
        // onPanStart有等待时间，所以加一个onTapDown
        onTapDown: _chartController.activeGraph != null
            ? (details) {
                if (stockPainter.isInMainRect(details.localPosition)) {
                  _beginMoveActiveGraph(_graphPainter, details.localPosition);
                }
              }
            : null,
        onPanStart: _chartController.activeGraph != null
            ? (details) {
                _beginMoveActiveGraph(_graphPainter, details.localPosition);
              }
            : null,
        onPanUpdate: _chartController.activeGraph != null
            ? (details) {
                _moveActiveGraph(_graphPainter, details.localPosition);
              }
            : null,
        onPanEnd: _chartController.activeGraph != null
            ? (details) {
                _activeGraphMoveEnd(_graphPainter);
              }
            : null,
        onLongPressStart: (details) {
          _beginMoveActiveGraph(_graphPainter, details.localPosition);
        },
        onLongPressMoveUpdate: (details) {
          _moveActiveGraph(_graphPainter, details.localPosition);
        },
        onLongPressEnd: (details) => _activeGraphMoveEnd(_graphPainter),
        child: paint,
      );
    } else {
      return paint;
    }
  }

  /// 手绘模式下，主图范围内被点击
  void _mainRectTappedWithEnableDraw(GraphPainter painter, Offset touchPoint) {
    if (widget.drawType == null) {
      painter.detectDrawnGraphs(touchPoint);
      // 是否有图形被激活
      if (painter.activeDrawnGraph == null) {
        widget.anyGraphDetected?.call(false);
      } else {
        widget.anyGraphDetected?.call(true);
      }
      notifyChanged();
    } else {
      _drawDrawnGraph(painter, touchPoint);
    }
  }

  /// 开始绘制图形
  void _drawDrawnGraph(GraphPainter painter, Offset touchPoint) {
    switch (widget.drawType!) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.hSegmentLine:
      case DrawnGraphType.vSegmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.rectangle:
      case DrawnGraphType.parallelLine:
      case DrawnGraphType.threeWave:
      case DrawnGraphType.fiveWave:
        _drawMultiAnchorGraph(painter, touchPoint);
        break;
      case DrawnGraphType.hStraightLine:
        _drawHorizontalStraightLine(painter, touchPoint);
        break;
    }
  }

  /// 绘制有多个锚点的图形
  void _drawMultiAnchorGraph(GraphPainter painter, Offset touchPoint) {
    final anchorCount = widget.drawType!.anchorCount;
    final drawnGraphs = List.of(_chartController.drawnGraphs);
    // 没有绘制的图形，或者绘制的图形都已经完成绘制，则添加新图形
    if (drawnGraphs.isEmpty || !drawnGraphs.last.isActive) {
      final drawingGraph = DrawnGraphEntity(
        drawType: widget.drawType!,
        values: [],
        isActive: true,
        style: widget.drawStyle!,
      );
      drawnGraphs.add(drawingGraph);
    }
    final lastDrawnGraph = drawnGraphs.last;
    // 继续绘制当前图形
    if (lastDrawnGraph.values.length < anchorCount) {
      var graphValue = painter.calculateTouchRawValue(touchPoint);
      if (graphValue == null) {
        widget.outMainTap?.call();
      } else {
        final sameValue = lastDrawnGraph.values.firstWhereOrNull((element) {
          return element.index == graphValue!.index &&
              element.price == graphValue.price;
        });
        // 是否已经存在相同的锚点
        if (sameValue != null) return;
        if (lastDrawnGraph.values.length == anchorCount - 1) {
          graphValue = painter.getLastAnchorGraphValue(
            widget.drawType!,
            lastDrawnGraph.values,
            graphValue,
          );
        }
        lastDrawnGraph.values.add(graphValue);
      }
    }
    if (lastDrawnGraph.values.length == anchorCount) {
      // 结束绘制当前图形
      painter.calculateDrawnGraphTime(lastDrawnGraph);
      widget.drawGraphProgress?.call(true);
    } else {
      widget.drawGraphProgress?.call(false);
    }
    _chartController.drawnGraphs = drawnGraphs;
  }

  /// 绘制水平直线
  void _drawHorizontalStraightLine(GraphPainter painter, Offset touchPoint) {
    final drawnGraphs = List.of(_chartController.drawnGraphs);
    final graphValue = painter.calculateTouchRawValue(touchPoint);
    if (graphValue == null) {
      widget.outMainTap?.call();
    } else {
      // 第二个点不会被绘制
      final graphValue2 = DrawGraphAnchor(
        index: graphValue.index! + 5,
        price: graphValue.price,
      );
      final drawingGraph = DrawnGraphEntity(
        drawType: widget.drawType!,
        values: [graphValue, graphValue2],
        isActive: true,
        style: widget.drawStyle!,
      );
      drawnGraphs.add(drawingGraph);
      // 结束绘制当前图形
      painter.calculateDrawnGraphTime(drawingGraph);
      _chartController.drawnGraphs = drawnGraphs;
      widget.drawGraphProgress?.call(true);
    }
  }

  /// 滑动、长按，开始移动正在编辑的图形
  void _beginMoveActiveGraph(GraphPainter painter, Offset position) {
    if (painter.activeDrawnGraph?.isLocked == true ||
        !painter.canBeginMoveActiveGraph(position)) {
      return;
    }
    _currentPressValue = painter.calculateTouchRawValue(position);
    // 可能为null
    _pressAnchorIndex = painter.detectAnchorPointIndex(position);
  }

  /// 滑动、长按手势移动正在编辑的图形
  void _moveActiveGraph(GraphPainter painter, Offset position) {
    if (_currentPressValue == null ||
        !painter.haveActiveDrawnGraph() ||
        painter.activeDrawnGraph?.isLocked == true) {
      return;
    }
    var nextValue = painter.calculateMoveRawValue(position);
    painter.moveActiveGraph(_currentPressValue!, nextValue, _pressAnchorIndex);
    _currentPressValue = nextValue;
    notifyChanged();
  }

  /// 编辑中的图形移动完成
  void _activeGraphMoveEnd(GraphPainter painter) {
    if (painter.activeDrawnGraph == null ||
        painter.activeDrawnGraph?.isLocked == true) {
      return;
    }
    painter.calculateDrawnGraphTime(painter.activeDrawnGraph);
    _currentPressValue = null;
    _pressAnchorIndex = null;
    widget.moveFinished?.call();
  }
}
