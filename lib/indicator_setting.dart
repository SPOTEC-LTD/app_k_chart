// Author: Dean.Liu
// DateTime: 2023/01/12 10:49

class IndicatorSetting {
  const IndicatorSetting({
    this.maDayList = const [5, 10, 30],
    this.emaDayList = const [5, 10, 30],
    this.bollSetting = const BollSetting(),
  });

  final List<int> maDayList;

  final List<int> emaDayList;

  final BollSetting bollSetting;

  IndicatorSetting.fromMap(Map<String, dynamic> map)
      : maDayList = List<int>.from(map['maDayList']),
        emaDayList = List<int>.from(map['emaDayList']),
        bollSetting = BollSetting.fromMap(map['bollSetting']);

  Map<String, Object?> toMap() {
    return {
      'maDayList': maDayList,
      'emaDayList': emaDayList,
      'bollSetting': bollSetting.toMap(),
    };
  }

  IndicatorSetting copyWith({
    List<int>? maDayList,
    List<int>? emaDayList,
    BollSetting? bollSetting,
  }) {
    return IndicatorSetting(
      maDayList: maDayList ?? this.maDayList,
      emaDayList: emaDayList ?? this.emaDayList,
      bollSetting: bollSetting ?? this.bollSetting,
    );
  }
}

class BollSetting {
  const BollSetting({this.n = 20, this.k = 2});

  final int n;
  final int k;

  BollSetting.fromMap(Map<String, dynamic> map)
      : n = map['n'],
        k = map['k'];

  Map<String, Object?> toMap() {
    return {'n': n, 'k': k};
  }

  BollSetting copyWith({int? n, int? k}) {
    return BollSetting(n: n ?? this.n, k: k ?? this.k);
  }
}
