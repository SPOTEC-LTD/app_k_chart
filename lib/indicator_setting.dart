// Author: Dean.Liu
// DateTime: 2023/01/12 10:49

class IndicatorSetting {
  const IndicatorSetting({
    this.maDayList = const [5, 10, 30],
    this.emaDayList = const [5, 10, 30],
    this.bollSetting = const BollSetting(),
    this.kdjSetting = const KdjSetting(),
    this.rsiDayList = const [6, 12, 24],
  });

  final List<int> maDayList;
  final List<int> emaDayList;
  final BollSetting bollSetting;
  final KdjSetting kdjSetting;
  final List<int> rsiDayList;

  IndicatorSetting.fromMap(Map<String, dynamic> map)
      : maDayList = List<int>.from(map['maDayList'] ?? const [5, 10, 30]),
        emaDayList = List<int>.from(map['emaDayList'] ?? const [5, 10, 30]),
        bollSetting = BollSetting.fromMap(map['bollSetting']),
        kdjSetting = KdjSetting.fromMap(map['kdjSetting']),
        rsiDayList = List<int>.from(map['rsiDayList'] ?? const [6, 12, 24]);

  Map<String, Object?> toMap() {
    return {
      'maDayList': maDayList,
      'emaDayList': emaDayList,
      'bollSetting': bollSetting.toMap(),
      'kdjSetting': kdjSetting.toMap(),
      'rsiDayList': rsiDayList,
    };
  }

  IndicatorSetting copyWith({
    List<int>? maDayList,
    List<int>? emaDayList,
    BollSetting? bollSetting,
    KdjSetting? kdjSetting,
    List<int>? rsiDayList,
  }) {
    return IndicatorSetting(
      maDayList: maDayList ?? this.maDayList,
      emaDayList: emaDayList ?? this.emaDayList,
      bollSetting: bollSetting ?? this.bollSetting,
      kdjSetting: kdjSetting ?? this.kdjSetting,
      rsiDayList: rsiDayList ?? this.rsiDayList,
    );
  }
}

class BollSetting {
  const BollSetting({this.n = 20, this.k = 2});

  final int n;
  final int k;

  BollSetting.fromMap(Map<String, dynamic> map)
      : n = map['n'] ?? 20,
        k = map['k'] ?? 2;

  Map<String, Object?> toMap() {
    return {'n': n, 'k': k};
  }

  BollSetting copyWith({int? n, int? k}) {
    return BollSetting(n: n ?? this.n, k: k ?? this.k);
  }
}

class KdjSetting {
  const KdjSetting({this.period = 9, this.m1 = 3, this.m2 = 3});

  /// 计算周期
  final int period;

  /// 移动平均周期1
  final int m1;

  /// 移动平均周期2
  final int m2;

  KdjSetting.fromMap(Map<String, dynamic> map)
      : period = map['period'] ?? 9,
        m1 = map['m1'] ?? 3,
        m2 = map['m2'] ?? 3;

  Map<String, Object?> toMap() {
    return {'period': period, 'm1': m1, 'm2': m2};
  }

  KdjSetting copyWith({int? period, int? m1, int? m2}) {
    return KdjSetting(
      period: period ?? this.period,
      m1: m1 ?? this.m1,
      m2: m2 ?? this.m2,
    );
  }
}
