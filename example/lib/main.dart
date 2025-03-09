import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/entity/draw_graph_entity.dart';
import 'package:k_chart/entity/draw_graph_preset_styles.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:k_chart/indicator_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

const _timeInterval = 24 * 60 * 60 * 1000;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<KLineEntity>? datas;
  List<DrawnGraphEntity>? _localGraphs;
  bool showLoading = true;
  bool _enableDraw = true;
  var _mainState = MainState.MA;
  List<SecondaryState> _secondaryStates = [
    SecondaryState.NONE,
    SecondaryState.VOLUME,
  ];
  bool isLine = true;
  bool _hideGrid = false;
  bool _showNowPrice = true;
  List<DepthEntity>? _bids, _asks;
  bool isChangeUI = false;
  bool _isTrendLine = false;
  bool _priceLeft = true;
  VerticalTextAlignment _verticalTextAlignment = VerticalTextAlignment.left;

  ChartStyle chartStyle = ChartStyle();
  ChartColors chartColors = ChartColors()..indicatorColors = [Colors.red];
  final _chartController = KChartController();
  DrawnGraphType? _drawType;
  var _showDrawnGraphs = true;
  var _indicatorSetting = IndicatorSetting(
    maDayList: [5, 10, 30, 60, 120],
    emaDayList: [5, 10, 30, 60],
    bollSetting: BollSetting(n: 30, k: 2),
    kdjSetting: KdjSetting(period: 10, m1: 4, m2: 5),
  );

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/depth.json').then((result) {
      final parseJson = json.decode(result);
      final tick = parseJson['tick'] as Map<String, dynamic>;
      final List<DepthEntity> bids = (tick['bids'] as List<dynamic>)
          .map<DepthEntity>(
              (item) => DepthEntity(item[0] as double, item[1] as double))
          .toList();
      final List<DepthEntity> asks = (tick['asks'] as List<dynamic>)
          .map<DepthEntity>(
              (item) => DepthEntity(item[0] as double, item[1] as double))
          .toList();
      initDepth(bids, asks);
    });
    SharedPreferences.getInstance().then((sp) {
      final graphsJson = sp.getString('spKey');
      if (graphsJson != null) {
        final graphsMap =
            (json.decode(graphsJson) as List).cast<Map<String, Object?>>();
        _localGraphs = graphsMap.map((e) {
          final graph = DrawnGraphEntity.fromMap(e);
          graph.values.forEach((value) {
            value.index = null;
          });
          return graph;
        }).toList();
      }
      getData('1day');
    });
  }

  void initDepth(List<DepthEntity>? bids, List<DepthEntity>? asks) {
    if (bids == null || asks == null || bids.isEmpty || asks.isEmpty) return;
    _bids = [];
    _asks = [];
    double amount = 0.0;
    bids.sort((left, right) => left.price.compareTo(right.price));
    //累加买入委托量
    bids.reversed.forEach((item) {
      amount += item.vol;
      item.vol = amount;
      _bids!.insert(0, item);
    });

    amount = 0.0;
    asks.sort((left, right) => left.price.compareTo(right.price));
    //累加卖出委托量
    asks.forEach((item) {
      amount += item.vol;
      item.vol = amount;
      _asks!.add(item);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final listView = ListView(
      shrinkWrap: true,
      physics: _enableDraw
          ? NeverScrollableScrollPhysics()
          : AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        Stack(children: <Widget>[
          Container(
            height: 450,
            width: double.infinity,
            child: KChartWidget(
              datas,
              chartStyle,
              chartColors,
              timeInterval: _timeInterval,
              chartController: _chartController,
              enableDraw: _enableDraw,
              drawType: _drawType,
              showDrawnGraphs: _showDrawnGraphs,
              presetDrawStyles: _createPreset(),
              drawStyle: DrawnGraphStyle.placeholder(),
              isLine: isLine,
              onSecondaryTap: () {
                print('Secondary Tap');
              },
              isTrendLine: _isTrendLine,
              mainState: _mainState,
              secondaryStates: _secondaryStates,
              fixedLength: 2,
              translations: kChartTranslations,
              showNowPrice: _showNowPrice,
              hideGrid: _hideGrid,
              isTapShowInfoDialog: false,
              verticalTextAlignment: _verticalTextAlignment,
              indicatorSetting: _indicatorSetting,
              drawGraphProgress: (isFinished) =>
                  _graphFinished(isFinished: isFinished),
              moveFinished: () => _graphFinished(isFinished: true),
              anyGraphDetected: (detected) {
                print('detected $detected');
              },
            ),
          ),
          if (showLoading)
            Container(
                width: double.infinity,
                height: 450,
                alignment: Alignment.center,
                child: const CircularProgressIndicator()),
        ]),
        buildButtons(),
        if (_bids != null && _asks != null)
          Container(
            height: 230,
            width: double.infinity,
            child: DepthChart(_bids!, _asks!, chartColors),
          )
      ],
    );
    return Scaffold(backgroundColor: Colors.black, body: listView);
  }

  Widget buildButtons() {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      children: <Widget>[
        Row(
          children: [
            Text('Enable Draw', style: TextStyle(color: Colors.white)),
            CupertinoSwitch(
              value: _enableDraw,
              onChanged: (enable) {
                setState(() {
                  _chartController.deactivateAllDrawnGraphs();
                  _enableDraw = enable;
                });
              },
            ),
            Text('Show Graphs', style: TextStyle(color: Colors.white)),
            CupertinoSwitch(
              value: _showDrawnGraphs,
              onChanged: (enable) {
                setState(() {
                  _showDrawnGraphs = enable;
                });
              },
            ),
          ],
        ),
        button("Segment", onPressed: () {
          _changeDrawType(DrawnGraphType.segmentLine);
        }),
        button("HorizontalSegment", onPressed: () {
          _changeDrawType(DrawnGraphType.hSegmentLine);
        }),
        button("VerticalSegment", onPressed: () {
          _changeDrawType(DrawnGraphType.vSegmentLine);
        }),
        button("Ray", onPressed: () {
          _changeDrawType(DrawnGraphType.rayLine);
        }),
        button("Straight", onPressed: () {
          _changeDrawType(DrawnGraphType.straightLine);
        }),
        button("HorizontalStraight", onPressed: () {
          _changeDrawType(DrawnGraphType.hStraightLine);
        }),
        button("ParallelLines", onPressed: () {
          _changeDrawType(DrawnGraphType.parallelLine);
        }),
        button("Rect", onPressed: () {
          _changeDrawType(DrawnGraphType.rectangle);
        }),
        button("ThreeWave", onPressed: () {
          _changeDrawType(DrawnGraphType.threeWave);
        }),
        button("FiveWave", onPressed: () {
          _changeDrawType(DrawnGraphType.fiveWave);
        }),
        button("Clear All", onPressed: () {
          _chartController.removeAllDrawnGraphs();
          _graphFinished(isFinished: true);
        }),
        button("Clear Active", onPressed: () {
          _chartController.removeActiveGraph();
          _graphFinished(isFinished: true);
        }),
        button("Toggle Lock Active", onPressed: () {
          _chartController.toggleActiveGraphLockState();
          _graphFinished(isFinished: true);
        }),
        button("Time Mode", onPressed: () => isLine = true),
        button("K Line Mode", onPressed: () => isLine = false),
        button("TrendLine", onPressed: () => _isTrendLine = !_isTrendLine),
        button("Line:MA", onPressed: () => _mainState = MainState.MA),
        button("Line:EMA", onPressed: () => _mainState = MainState.EMA),
        button("Line:BOLL", onPressed: () => _mainState = MainState.BOLL),
        button("Hide Line", onPressed: () => _mainState = MainState.NONE),
        button("Secondary Chart:VOLUME",
            onPressed: () => _addSecondaryState(SecondaryState.VOLUME)),
        button("Secondary Chart:MACD",
            onPressed: () => _addSecondaryState(SecondaryState.MACD)),
        button("Secondary Chart:KDJ",
            onPressed: () => _addSecondaryState(SecondaryState.KDJ)),
        button("Secondary Chart:RSI",
            onPressed: () => _addSecondaryState(SecondaryState.RSI)),
        button("Secondary Chart:WR",
            onPressed: () => _addSecondaryState(SecondaryState.WR)),
        button("Secondary Chart:CCI",
            onPressed: () => _addSecondaryState(SecondaryState.CCI)),
        button("Secondary Chart:Hide", onPressed: () => _secondaryStates = []),
        button(_hideGrid ? "Show Grid" : "Hide Grid",
            onPressed: () => _hideGrid = !_hideGrid),
        button(_showNowPrice ? "Hide Now Price" : "Show Now Price",
            onPressed: () => _showNowPrice = !_showNowPrice),
        button("Customize UI", onPressed: () {
          setState(() {
            this.isChangeUI = !this.isChangeUI;
            if (this.isChangeUI) {
              chartColors.selectBorderColor = Colors.red;
              chartColors.selectFillColor = Colors.red;
              chartColors.lineFillColor = Colors.red;
              chartColors.kLineColor = Colors.yellow;
            } else {
              chartColors.selectBorderColor = Color(0xff6C7A86);
              chartColors.selectFillColor = Color(0xff0D1722);
              chartColors.lineFillColor = Color(0x554C86CD);
              chartColors.kLineColor = Color(0xff4C86CD);
            }
          });
        }),
        button("Change PriceTextPaint",
            onPressed: () => setState(() {
                  _priceLeft = !_priceLeft;
                  if (_priceLeft) {
                    _verticalTextAlignment = VerticalTextAlignment.left;
                  } else {
                    _verticalTextAlignment = VerticalTextAlignment.right;
                  }
                })),
      ],
    );
  }

  Widget button(String text, {VoidCallback? onPressed}) {
    return TextButton(
      onPressed: () {
        if (onPressed != null) {
          onPressed();
          setState(() {});
        }
      },
      child: Text(text, style: TextStyle(color: Colors.white)),
      style: TextButton.styleFrom(
        minimumSize: const Size(88, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2.0)),
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  DrawGraphPresetStyles _createPreset() {
    return DrawGraphPresetStyles(
      stokeColors: [
        Color(0xFFF34E6C),
        Color(0xFFDA7D0F),
        Color(0xFFF0E717),
        Color(0xFF73E162),
        Color(0xFF0FB5DA),
        Color(0xFFDA54F0),
      ],
      fillColors: [
        Color(0x66F34E6C),
        Color(0x66DA7D0F),
        Color(0x66F0E717),
        Color(0x6673E162),
        Color(0x660FB5DA),
        Color(0x66DA54F0),
      ],
      dashedLines: [
        null,
        [2, 2],
        [4, 4],
      ],
      lineWidths: [1, 2, 3],
    );
  }

  void getData(String period) {
    /*
     * 可以翻墙使用方法1加载数据，不可以翻墙使用方法2加载数据，默认使用方法1加载最新数据
     */
    // final Future<String> future = getChatDataFromInternet(period);
    final Future<String> future = getChatDataFromJson();
    future.then((String result) {
      solveChatData(result);
    }).catchError((_) {
      showLoading = false;
      setState(() {});
      print('### datas error $_');
    });
  }

  //获取火币数据，需要翻墙
  Future<String> getChatDataFromInternet(String? period) async {
    var url =
        'https://api.huobi.br.com/market/history/kline?period=${period ?? '1day'}&size=300&symbol=btcusdt';
    late String result;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      result = response.body;
    } else {
      print('Failed getting IP address');
    }
    return result;
  }

  // 如果你不能翻墙，可以使用这个方法加载数据
  Future<String> getChatDataFromJson() async {
    return rootBundle.loadString('assets/chatData.json');
  }

  void solveChatData(String result) {
    final Map parseJson = json.decode(result) as Map<dynamic, dynamic>;
    final list = parseJson['data'] as List<dynamic>;
    datas = list
        .map((item) => KLineEntity.fromJson(item as Map<String, dynamic>))
        .toList()
        .reversed
        .toList()
        .cast<KLineEntity>();
    DataUtil.calculate(datas!, setting: _indicatorSetting);
    showLoading = false;

    _localGraphs?.forEach((graph) {
      graph.values.forEach((value) {
        value.index = _calculateIndexFromTime(value.time, datas!);
      });
    });
    setState(() {
      if (_localGraphs != null) {
        _chartController.drawnGraphs = _localGraphs!;
      }
    });
  }

  double? _calculateIndexFromTime(int? time, List<KLineEntity> datas) {
    if (time == null || datas.isEmpty) return null;
    final nextIndex = datas.indexWhere((data) {
      if (data.time! > time) {
        return true;
      } else {
        return false;
      }
    });
    int baseIndex;
    int interval;
    if (nextIndex == -1 || nextIndex == 0) {
      baseIndex = 0;
      interval = _timeInterval;
    } else {
      baseIndex = nextIndex - 1;
      final baseTime = datas[baseIndex].time!;
      final nextTime = datas[nextIndex].time!;
      interval = nextTime - baseTime;
    }
    return (time - datas[baseIndex].time!) / interval + baseIndex;
  }

  void _graphFinished({required bool isFinished}) {
    print(isFinished);
    if (!isFinished) return;
    _changeDrawType(null);
    final graphsMap =
        _chartController.drawnGraphs.map((e) => e.toMap()).toList();
    final graphsJson = json.encode(graphsMap);
    print(graphsJson);
    SharedPreferences.getInstance().then((sp) {
      sp.setString('spKey', graphsJson);
    });
  }

  void _changeDrawType(DrawnGraphType? type) {
    if (type != null) {
      _chartController.deactivateAllDrawnGraphs();
    }
    setState(() {
      _drawType = type;
    });
  }

  void _addSecondaryState(SecondaryState state) {
    _secondaryStates.add(state);
    if (_secondaryStates.length > 2) {
      _secondaryStates.removeAt(0);
    }
  }
}
