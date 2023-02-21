import 'dart:math';

import 'package:k_chart/indicator_setting.dart';

import '../entity/index.dart';

class DataUtil {
  static calculate(
    List<KLineEntity> dataList, {
    IndicatorSetting setting = const IndicatorSetting(),
  }) {
    calcMA(dataList, setting.maDayList);
    calcEMA(dataList, setting.emaDayList);
    final bollSetting = setting.bollSetting;
    calcBOLL(dataList, bollSetting.n, bollSetting.k);
    calcVolumeMA(dataList);
    final kdjSetting = setting.kdjSetting;
    calcKDJ(dataList, kdjSetting.period, kdjSetting.m1, kdjSetting.m2);
    calcMACD(dataList);
    calcRSI(dataList, setting.rsiDayList);
    calcWR(dataList, setting.wrDayList);
    calcCCI(dataList);
  }

  static calcMA(List<KLineEntity> dataList, List<int> maDayList) {
    List<double> ma = List<double>.filled(maDayList.length, 0);

    if (dataList.isNotEmpty) {
      for (int i = 0; i < dataList.length; i++) {
        KLineEntity entity = dataList[i];
        final closePrice = entity.close;
        entity.maValueList = List<double>.filled(maDayList.length, 0);

        for (int j = 0; j < maDayList.length; j++) {
          final day = maDayList[j];
          // 先加
          ma[j] += closePrice;
          if (i == day - 1) {
            entity.maValueList?[j] = ma[j] / day;
          } else if (i >= day) {
            // 后减
            ma[j] -= dataList[i - day].close;
            entity.maValueList?[j] = ma[j] / day;
          } else {
            entity.maValueList?[j] = 0;
          }
        }
      }
    }
  }

  static calcEMA(List<KLineEntity> dataList, List<int> maDayList) {
    // 将指定天数之前的ema值设置为0
    void removeValueBeforeDay(int dayIndex) {
      final day = maDayList[dayIndex];
      for (int i = 0; i < dataList.length; i++) {
        if (i >= day - 1) return;
        KLineEntity entity = dataList[i];
        entity.emaValueList?[dayIndex] = 0;
      }
    }

    List<double> preEmaValues =
        List<double>.filled(maDayList.length, dataList.first.close);
    if (dataList.isNotEmpty) {
      for (int i = 0; i < dataList.length; i++) {
        KLineEntity entity = dataList[i];
        final closePrice = entity.close;
        entity.emaValueList = List<double>.filled(maDayList.length, 0);

        for (int j = 0; j < maDayList.length; j++) {
          final day = maDayList[j];
          final factor = 2 / (day + 1);
          final preEmaValue = preEmaValues[j];
          if (i == 0) {
            entity.emaValueList?[j] = preEmaValue;
          } else {
            final ema = factor * (closePrice - preEmaValue) + preEmaValue;
            entity.emaValueList?[j] = ema;
            preEmaValues[j] = ema;
            if (i == day) {
              removeValueBeforeDay(j);
            }
          }
        }
      }
    }
  }

  static void calcBOLL(List<KLineEntity> dataList, int n, int k) {
    _calcBOLLMA(n, dataList);
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      if (i >= n) {
        double md = 0;
        for (int j = i - n + 1; j <= i; j++) {
          double c = dataList[j].close;
          double m = entity.BOLLMA!;
          double value = c - m;
          md += value * value;
        }
        md = md / n;
        md = sqrt(md);
        entity.mb = entity.BOLLMA!;
        entity.up = entity.mb! + k * md;
        entity.dn = entity.mb! - k * md;
      }
    }
  }

  static void _calcBOLLMA(int day, List<KLineEntity> dataList) {
    double ma = 0;
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      ma += entity.close;
      if (i == day - 1) {
        entity.BOLLMA = ma / day;
      } else if (i >= day) {
        ma -= dataList[i - day].close;
        entity.BOLLMA = ma / day;
      } else {
        entity.BOLLMA = null;
      }
    }
  }

  static void calcMACD(List<KLineEntity> dataList) {
    double ema12 = 0;
    double ema26 = 0;
    double dif = 0;
    double dea = 0;
    double macd = 0;

    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      final closePrice = entity.close;
      if (i == 0) {
        ema12 = closePrice;
        ema26 = closePrice;
      } else {
        // EMA（12） = 前一日EMA（12） X 11/13 + 今日收盘价 X 2/13
        ema12 = ema12 * 11 / 13 + closePrice * 2 / 13;
        // EMA（26） = 前一日EMA（26） X 25/27 + 今日收盘价 X 2/27
        ema26 = ema26 * 25 / 27 + closePrice * 2 / 27;
      }
      // DIF = EMA（12） - EMA（26） 。
      // 今日DEA = （前一日DEA X 8/10 + 今日DIF X 2/10）
      // 用（DIF-DEA）*2即为MACD柱状图。
      dif = ema12 - ema26;
      dea = dea * 8 / 10 + dif * 2 / 10;
      macd = (dif - dea) * 2;
      entity.dif = dif;
      entity.dea = dea;
      entity.macd = macd;
    }
  }

  static void calcVolumeMA(List<KLineEntity> dataList) {
    double volumeMa5 = 0;
    double volumeMa10 = 0;

    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entry = dataList[i];

      volumeMa5 += entry.vol;
      volumeMa10 += entry.vol;

      if (i == 4) {
        entry.MA5Volume = (volumeMa5 / 5);
      } else if (i > 4) {
        volumeMa5 -= dataList[i - 5].vol;
        entry.MA5Volume = volumeMa5 / 5;
      } else {
        entry.MA5Volume = 0;
      }

      if (i == 9) {
        entry.MA10Volume = volumeMa10 / 10;
      } else if (i > 9) {
        volumeMa10 -= dataList[i - 10].vol;
        entry.MA10Volume = volumeMa10 / 10;
      } else {
        entry.MA10Volume = 0;
      }
    }
  }

  static void calcRSI(List<KLineEntity> dataList, List<int> dayList) {
    if (dayList.isEmpty) return;
    var lastClosePrice = dataList[0].close;
    Map<String, dynamic> result = {};
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      entity.rsiValueList = [];
      final double closePrice = entity.close;
      final rMax = max(0, closePrice - lastClosePrice);
      final rAbs = (closePrice - lastClosePrice).abs();

      for (final day in dayList) {
        final lastSm = 'lastSm$day';
        final lastSa = 'lastSa$day';
        result[lastSm] = (rMax + (day - 1) * (result[lastSm] ?? 0)) / day;
        result[lastSa] = (rAbs + (day - 1) * (result[lastSa] ?? 0)) / day;
        if (i < day - 1) {
          entity.rsiValueList?.add(null);
        } else {
          entity.rsiValueList?.add(result[lastSm] / result[lastSa] * 100);
        }
      }
      lastClosePrice = closePrice;
    }
  }

  static void calcKDJ(
    List<KLineEntity> dataList,
    int period,
    int m1,
    int m2,
  ) {
    if (dataList.isEmpty) return;
    var preK = 50.0;
    var preD = 50.0;
    final tmp = dataList.first;
    tmp.k = preK;
    tmp.d = preD;
    tmp.j = 50.0;
    for (int i = 1; i < dataList.length; i++) {
      final entity = dataList[i];
      final n = max(0, i - period);
      var low = entity.low;
      var high = entity.high;
      for (int j = n; j < i; j++) {
        final t = dataList[j];
        if (t.low < low) {
          low = t.low;
        }
        if (t.high > high) {
          high = t.high;
        }
      }
      final cur = entity.close;
      var rsv = (cur - low) * 100.0 / (high - low);
      rsv = rsv.isNaN ? 0 : rsv;
      final k = ((m1 - 1) * preK + rsv) / m1;
      final d = ((m2 - 1) * preD + k) / m2;
      final j = 3 * k - 2 * d;
      preK = k;
      preD = d;
      entity.k = k;
      entity.d = d;
      entity.j = j;
    }
  }

  static void calcWR(List<KLineEntity> dataList, List<int> dayList) {
    if (dayList.isEmpty) return;
    Map<String, List<KLineEntity>> windowData = {};
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      entity.wrValueList = [];
      for (final day in dayList) {
        final wrKey = 'wr$day';
        if (windowData[wrKey] == null) {
          windowData[wrKey] = [];
        }
        final windowDataList = windowData[wrKey]!;
        // 先加入
        windowDataList.add(entity);

        double maxP = double.minPositive;
        double minP = double.maxFinite;
        for (final data in windowDataList) {
          maxP = max(maxP, data.high);
          minP = min(minP, data.low);
        }
        if (i < day - 1) {
          entity.wrValueList?.add(null);
        } else {
          final wr = maxP > minP
              ? -100.0 * (maxP - dataList[i].close) / (maxP - minP)
              : -100.0;
          entity.wrValueList?.add(wr);
        }
        // 如果超过长度再移除
        if (windowDataList.length == day) {
          windowDataList.removeAt(0);
        }
      }
    }
  }

  static void calcCCI(List<KLineEntity> dataList) {
    final size = dataList.length;
    final count = 14;
    for (int i = 0; i < size; i++) {
      final kline = dataList[i];
      final tp = (kline.high + kline.low + kline.close) / 3;
      final start = max(0, i - count + 1);
      var amount = 0.0;
      var len = 0;
      for (int n = start; n <= i; n++) {
        amount += (dataList[n].high + dataList[n].low + dataList[n].close) / 3;
        len++;
      }
      final ma = amount / len;
      amount = 0.0;
      for (int n = start; n <= i; n++) {
        amount +=
            (ma - (dataList[n].high + dataList[n].low + dataList[n].close) / 3)
                .abs();
      }
      final md = amount / len;
      kline.cci = ((tp - ma) / 0.015 / md);
      if (kline.cci!.isNaN) {
        kline.cci = 0.0;
      }
    }
  }
}
