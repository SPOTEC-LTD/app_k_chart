import 'dart:async';

import 'package:flutter/material.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/extension/map_ext.dart';
import 'package:k_chart/flutter_k_chart.dart';

import 'entity/draw_graph_entity.dart';

enum MainState { MA, BOLL, NONE }

enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool isTapShowInfoDialog; //是否开启单击显示详情数据
  final bool hideGrid;
  @Deprecated('Use `translations` instead.')
  final bool isChinese;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material风格的信息弹窗
  final Map<String, ChartTranslations> translations;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final List<int> maDayList;
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

  /// 画图点击事件超出主图范围
  final VoidCallback? outMainTap;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    required this.isTrendLine,
    this.mainState = MainState.MA,
    this.secondaryState = SecondaryState.MACD,
    this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    @Deprecated('Use `translations` instead.') this.isChinese = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.translations = kChartTranslations,
    this.onLoadMore,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
    this.chartController,
    this.enableDraw = false,
    this.outMainTap,
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
  DrawGraphRawValue? _currentPressValue;

  /// 选中锚点在DrawGraphEntity的value数组中的索引
  int? _pressAnchorIndex;

  /// 是否可以绘制手画的图形
  bool get _enableDraw => widget.enableDraw && !widget.isLine;

  final _defaultChartController = KChartController();

  KChartController get _chartController =>
      widget.chartController ?? _defaultChartController;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final _painter = ChartPainter(
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
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      verticalTextAlignment: widget.verticalTextAlignment,
      dateTimeFormat: gerRealDateTimeFormat(),
      drawnGraphs: _chartController.drawnGraphs,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        return GestureDetector(
          onTapUp: (details) {
            if (!widget.isTrendLine &&
                widget.onSecondaryTap != null &&
                _painter.isInSecondaryRect(details.localPosition)) {
              widget.onSecondaryTap!();
            }

            if (!widget.isTrendLine &&
                _painter.isInMainRect(details.localPosition)) {
              if (_enableDraw) {
                _mainRectTappedWithEnableDraw(_painter, details.localPosition);
              } else {
                isOnTap = true;
                if (mSelectX != details.localPosition.dx &&
                    widget.isTapShowInfoDialog) {
                  mSelectX = details.localPosition.dx;
                  mSelectY = details.localPosition.dy;
                  notifyChanged();
                }
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
            if (_enableDraw) {
              _beginMoveActiveGraph(_painter, details.localPosition);
            } else {
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
            }
          },
          onLongPressMoveUpdate: (details) {
            if (_enableDraw) {
              _moveActiveGraph(_painter, details.localPosition);
            } else {
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
            }
          },
          onLongPressEnd: (details) {
            if (_enableDraw) {
              _currentPressValue = null;
            } else {
              isLongPress = false;
              enableCordRecord = true;
              mInfoWindowStream?.sink.add(null);
              notifyChanged();
            }
          },
          child: Stack(
            children: <Widget>[
              CustomPaint(
                size: Size(double.infinity, double.infinity),
                painter: _painter,
              ),
              if (widget.showInfoDialog) _buildInfoDialog()
            ],
          ),
        );
      },
    );
  }

  void _onChartController() {
    isLongPress = false;
    isOnTap = false;
    mInfoWindowStream?.sink.add(null);
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
            if (widget.volHidden == false && entityAmount != null)
              entityAmount.toInt().toString()
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
                final translations = widget.isChinese
                    ? kChartTranslations['zh_CN']!
                    : widget.translations.of(context);

                return _buildItem(
                  infos[index],
                  translations.byIndex(index),
                );
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith("+"))
      color = widget.chartColors.infoWindowUpColor;
    else if (info.startsWith("-")) color = widget.chartColors.infoWindowDnColor;
    final infoWidget = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
            child: Text("$infoName",
                style: TextStyle(
                    color: widget.chartColors.infoWindowTitleColor,
                    fontSize: 10.0))),
        Text(info, style: TextStyle(color: color, fontSize: 10.0)),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.5),
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

    int firstTime = widget.datas!.first.time ?? 0;
    int secondTime = widget.datas![1].time ?? 0;
    int time = secondTime - firstTime;
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

  void _mainRectTappedWithEnableDraw(ChartPainter painter, Offset touchPoint) {
    if (_chartController.drawType == null) {
      painter.detectDrawnGraphs(touchPoint);
      notifyChanged();
    } else {
      _drawDrawnGraph(painter, touchPoint);
    }
  }

  void _drawDrawnGraph(ChartPainter painter, Offset touchPoint) {
    switch (_chartController.drawType!) {
      case DrawnGraphType.segmentLine:
      case DrawnGraphType.rayLine:
      case DrawnGraphType.straightLine:
      case DrawnGraphType.rectangle:
        _drawTwoAnchorGraph(painter, touchPoint);
        break;
    }
  }

  /// 绘制只有两个锚点的图形
  void _drawTwoAnchorGraph(ChartPainter painter, Offset touchPoint) {
    final drawnGraphs = List.of(_chartController.drawnGraphs);
    if (drawnGraphs.isEmpty || drawnGraphs.last.values.length == 2) {
      final drawingGraph = DrawnGraphEntity(
        drawType: _chartController.drawType!,
        values: [],
        isActive: true,
      );
      drawnGraphs.add(drawingGraph);
    }
    // 继续绘制当前图形
    if (drawnGraphs.last.values.length < 2) {
      var graphValue = painter.calculateTouchRawValue(touchPoint);
      if (graphValue == null) {
        widget.outMainTap?.call();
      } else {
        drawnGraphs.last.values.add(graphValue);
      }
    }
    // 结束绘制当前图形
    if (drawnGraphs.last.values.length == 2) {
      _chartController.drawType = null;
    }
    _chartController.drawnGraphs = drawnGraphs;
  }

  /// 长按开始移动正在编辑的图形
  void _beginMoveActiveGraph(ChartPainter painter, Offset position) {
    if (!painter.canBeginMoveActiveGraph(position)) {
      return;
    }
    _currentPressValue = painter.calculateTouchRawValue(position);
    // 可能为null
    _pressAnchorIndex = painter.detectAnchorPointIndex(position);
  }

  /// 移动正在编辑的图形
  void _moveActiveGraph(ChartPainter painter, Offset position) {
    if (_currentPressValue == null || !painter.haveActiveDrawnGraph()) {
      return;
    }
    var nextValue = painter.calculateMoveRawValue(position);
    painter.moveActiveGraph(_currentPressValue!, nextValue, _pressAnchorIndex);
    _currentPressValue = nextValue;
    notifyChanged();
  }
}
